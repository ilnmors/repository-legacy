#!/bin/bash
set -euo pipefail

out_dir="${OUT_DIR:-/etc/smartctl-exporter}"
smartctl_bin="${SMARTCTL:-/usr/sbin/smartctl}"

tmp="$(mktemp "${out_dir}/smartctl.prom.XXXXXX")"
out="${out_dir}/smartctl.prom"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

discover_devices() {
  for sys in /sys/class/block/*; do
    dev="${sys##*/}"

    [ -e "$sys/device" ] || continue
    [ ! -e "$sys/partition" ] || continue

    case "$dev" in
      loop*|ram*|zram*|dm-*|md*|nbd*|sr*|fd*)
        continue
        ;;
    esac

    sys_path="$(readlink -f "$sys" 2>/dev/null || true)"

    case "$sys_path" in
      *usb*)
        continue
        ;;
      */virtual/*)
        continue
        ;;
    esac

    [ -b "/dev/$dev" ] || continue
    printf '%s\n' "/dev/$dev"
  done | sort -V
}

write_header() {
  cat <<'HDR'
# HELP smartctl_version smartctl version
# TYPE smartctl_version gauge
# HELP smartctl_device Device info
# TYPE smartctl_device gauge
# HELP smartctl_devices Number of devices configured or dynamically discovered
# TYPE smartctl_devices gauge
# HELP smartctl_device_capacity_blocks Device capacity in blocks
# TYPE smartctl_device_capacity_blocks gauge
# HELP smartctl_device_capacity_bytes Device capacity in bytes
# TYPE smartctl_device_capacity_bytes gauge
# HELP smartctl_device_nvme_capacity_bytes NVMe device total capacity bytes
# TYPE smartctl_device_nvme_capacity_bytes gauge
# HELP smartctl_device_block_size Device block size
# TYPE smartctl_device_block_size gauge
# HELP smartctl_device_interface_speed Device interface speed, bits per second
# TYPE smartctl_device_interface_speed gauge
# HELP smartctl_device_attribute Device attributes
# TYPE smartctl_device_attribute gauge
# HELP smartctl_device_power_on_seconds Device power on seconds
# TYPE smartctl_device_power_on_seconds counter
# HELP smartctl_device_rotation_rate Device rotation rate
# TYPE smartctl_device_rotation_rate gauge
# HELP smartctl_device_temperature Device temperature celsius
# TYPE smartctl_device_temperature gauge
# HELP smartctl_device_power_cycle_count Device power cycle count
# TYPE smartctl_device_power_cycle_count counter
# HELP smartctl_device_percentage_used Device write percentage used
# TYPE smartctl_device_percentage_used counter
# HELP smartctl_device_available_spare Normalized percentage of the remaining spare capacity available
# TYPE smartctl_device_available_spare counter
# HELP smartctl_device_available_spare_threshold Available spare threshold
# TYPE smartctl_device_available_spare_threshold counter
# HELP smartctl_device_critical_warning Critical warnings for the state of the controller
# TYPE smartctl_device_critical_warning counter
# HELP smartctl_device_media_errors Media/data integrity errors
# TYPE smartctl_device_media_errors counter
# HELP smartctl_device_num_err_log_entries Number of error information log entries
# TYPE smartctl_device_num_err_log_entries counter
# HELP smartctl_device_bytes_read Device bytes read
# TYPE smartctl_device_bytes_read counter
# HELP smartctl_device_bytes_written Device bytes written
# TYPE smartctl_device_bytes_written counter
# HELP smartctl_device_smart_status General smart status
# TYPE smartctl_device_smart_status gauge
# HELP smartctl_device_smartctl_exit_status Exit status of smartctl on device
# TYPE smartctl_device_smartctl_exit_status gauge
# HELP smartctl_device_state Device state
# TYPE smartctl_device_state gauge
# HELP smartctl_device_statistics Device statistics
# TYPE smartctl_device_statistics gauge
# HELP smartctl_device_error_log_count Device SMART error log count
# TYPE smartctl_device_error_log_count gauge
# HELP smartctl_device_self_test_log_count Device SMART self test log count
# TYPE smartctl_device_self_test_log_count gauge
# HELP smartctl_device_self_test_log_error_count Device SMART self test log error count
# TYPE smartctl_device_self_test_log_error_count gauge
# HELP smartctl_device_erc_seconds Device SMART Error Recovery Control Seconds
# TYPE smartctl_device_erc_seconds gauge
# HELP smartctl_scsi_grown_defect_list Device SCSI grown defect list counter
# TYPE smartctl_scsi_grown_defect_list gauge
# HELP smartctl_read_errors_corrected_by_rereads_rewrites Read Errors Corrected by ReReads/ReWrites
# TYPE smartctl_read_errors_corrected_by_rereads_rewrites gauge
# HELP smartctl_read_errors_corrected_by_eccfast Read Errors Corrected by ECC Fast
# TYPE smartctl_read_errors_corrected_by_eccfast gauge
# HELP smartctl_read_errors_corrected_by_eccdelayed Read Errors Corrected by ECC Delayed
# TYPE smartctl_read_errors_corrected_by_eccdelayed gauge
# HELP smartctl_read_total_uncorrected_errors Read Total Uncorrected Errors
# TYPE smartctl_read_total_uncorrected_errors gauge
# HELP smartctl_write_errors_corrected_by_rereads_rewrites Write Errors Corrected by ReReads/ReWrites
# TYPE smartctl_write_errors_corrected_by_rereads_rewrites gauge
# HELP smartctl_write_errors_corrected_by_eccfast Write Errors Corrected by ECC Fast
# TYPE smartctl_write_errors_corrected_by_eccfast gauge
# HELP smartctl_write_errors_corrected_by_eccdelayed Write Errors Corrected by ECC Delayed
# TYPE smartctl_write_errors_corrected_by_eccdelayed gauge
# HELP smartctl_write_total_uncorrected_errors Write Total Uncorrected Errors
# TYPE smartctl_write_total_uncorrected_errors gauge
HDR
}

emit_version() {
  jq -r '
    def esc: tostring | gsub("\\\\";"\\\\") | gsub("\"";"\\\"");
    (.json_format_version // [0,0]) as $jv
    | (.smartctl.version // [0,0]) as $sv
    | "smartctl_version{json_format_version=\"\($jv[0]).\($jv[1])\",smartctl_version=\"\($sv[0]).\($sv[1])\",svn_revision=\"\((.smartctl.svn_revision // "")|esc)\",build_info=\"\((.smartctl.build_info // "")|esc)\"} 1"
  '
}

emit_metrics() {
  jq -r '
    def esc: tostring | gsub("\\\\";"\\\\") | gsub("\"";"\\\"");
    def lbl($pairs): $pairs | map("\(.[0])=\"\(.[1]|esc)\"") | join(",");
    def n($x):
      if $x == true then 1
      elif $x == false then 0
      elif $x == null then 0
      else $x
      end;
    def emit($name; $pairs; $value):
      "\($name){\(lbl($pairs))} \(n($value))";
    def emit_if_exists($name; $pairs; $value):
      if $value == null then empty else emit($name; $pairs; $value) end;
    def trimstr: tostring | gsub("^\\s+|\\s+$";"");
    def build_device_label($name; $type):
      ($name | sub("^/dev/(disk/by-id/|disk/by-path/|)"; "") | gsub("/"; "_")) as $base
      | if ($type | contains(",")) then
          "\($base)_\($type | gsub(","; "_"))"
        else
          $base
        end;
    def longflags($obj; $names):
      [$names[] as $k | select(($obj[$k] // false) == true) | $k] | join(",");

    . as $j
    | build_device_label(($j.device.name // ""); ($j.device.type // "")) as $device
    | ($j.device.type // "") as $interface
    | ($j.device.protocol // "") as $protocol
    | [
        emit("smartctl_device_smartctl_exit_status"; [["device", $device]]; $j.smartctl.exit_status),

        emit("smartctl_device"; [
          ["device", $device],
          ["interface", $interface],
          ["protocol", $protocol],
          ["model_family", (($j.model_family // "unknown") | trimstr)],
          ["model_name", (($j.model_name // $j.scsi_model_name // "unknown") | if . == "" then "unknown" else . end | trimstr)],
          ["serial_number", (($j.serial_number // "") | trimstr)],
          ["ata_additional_product_id", ($j.ata_additional_product_id // "unknown")],
          ["firmware_version", ($j.firmware_version // "")],
          ["ata_version", ($j.ata_version.string // "")],
          ["sata_version", ($j.sata_version.string // "")],
          ["form_factor", ($j.form_factor.name // "")],
          ["scsi_vendor", ($j.scsi_vendor // "")],
          ["scsi_product", ($j.scsi_product // "")],
          ["scsi_revision", ($j.scsi_revision // "")],
          ["scsi_version", ($j.scsi_version // "")]
        ]; 1),

        emit("smartctl_device_capacity_blocks"; [["device", $device]]; $j.user_capacity.blocks),
        emit("smartctl_device_capacity_bytes"; [["device", $device]]; $j.user_capacity.bytes),
        emit_if_exists("smartctl_device_nvme_capacity_bytes"; [["device", $device]]; $j.nvme_total_capacity),

        emit("smartctl_device_block_size"; [["device", $device], ["blocks_type", "logical"]]; $j.logical_block_size),
        emit("smartctl_device_block_size"; [["device", $device], ["blocks_type", "physical"]]; $j.physical_block_size),

        (if $j.interface_speed != null then
          ($j.interface_speed
            | to_entries[]
            | select(.key == "max" or .key == "current")
            | emit("smartctl_device_interface_speed";
                [["device", $device], ["speed_type", .key]];
                n(.value.units_per_second) * n(.value.bits_per_unit)))
         else empty end),

        ($j.ata_smart_attributes.table[]?
          | . as $a
          | longflags(($a.flags // {}); ["prefailure", "updated_online", "performance", "error_rate", "event_count", "auto_keep"]) as $lf
          | [
              ["value",  $a.value],
              ["worst",  $a.worst],
              ["thresh", $a.thresh],
              ["raw",    $a.raw.value]
            ][]
          | emit("smartctl_device_attribute"; [
              ["device", $device],
              ["attribute_name", (($a.name // "") | trimstr)],
              ["attribute_flags_short", (($a.flags.string // "") | trimstr)],
              ["attribute_flags_long", $lf],
              ["attribute_value_type", .[0]],
              ["attribute_id", (($a.id // "") | tostring)]
            ]; .[1])
        ),

        (if $j.power_on_time != null then
          emit("smartctl_device_power_on_seconds"; [["device", $device]];
            n($j.power_on_time.hours) * 3600 + n($j.power_on_time.minutes) * 60)
         else empty end),

        (if n($j.rotation_rate) > 0 then
          emit("smartctl_device_rotation_rate"; [["device", $device]]; $j.rotation_rate)
         else empty end),

        ($j.temperature? // {}
          | to_entries[]?
          | emit("smartctl_device_temperature"; [["device", $device], ["temperature_type", .key]]; .value)
        ),

        (if $j.power_cycle_count != null then
          emit("smartctl_device_power_cycle_count"; [["device", $device]]; $j.power_cycle_count)
         elif $j.scsi_start_stop_cycle_counter.accumulated_start_stop_cycles != null then
          emit("smartctl_device_power_cycle_count"; [["device", $device]]; $j.scsi_start_stop_cycle_counter.accumulated_start_stop_cycles)
         else empty end),

        (if $j.ata_sct_status != null then
          emit("smartctl_device_state"; [["device", $device]]; $j.ata_sct_status.device_state)
         else empty end),

        (if $j.smart_status != null then
          emit("smartctl_device_smart_status"; [["device", $device]];
            if $j.smart_status.passed == true then 1
            elif $j.smart_status.passed == false then 0
            else $j.smart_status.passed
            end)
         else empty end),

        ($j.ata_device_statistics.pages[]?
          | select(((.name // "") | trimstr) != "Vendor Specific Statistics") as $page
          | $page.table[]?
          | emit("smartctl_device_statistics"; [
              ["device", $device],
              ["statistic_table", (($page.name // "") | trimstr)],
              ["statistic_name", ((.name // "") | trimstr)],
              ["statistic_flags_short", ((.flags.string // "") | trimstr)],
              ["statistic_flags_long", longflags((.flags // {}); ["valid", "normalized", "supports_dsn", "monitored_condition_met"])]
            ]; .value)
        ),

        ($j.sata_phy_event_counters.table[]?
          | emit("smartctl_device_statistics"; [
              ["device", $device],
              ["statistic_table", "SATA PHY Event Counters"],
              ["statistic_name", ((.name // "") | trimstr)],
              ["statistic_flags_short", "V---"],
              ["statistic_flags_long", "valid"]
            ]; .value)
        ),

        ($j.ata_smart_error_log? // {}
          | to_entries[]?
          | emit("smartctl_device_error_log_count"; [["device", $device], ["error_log_type", .key]]; .value.count)
        ),

        ($j.ata_smart_self_test_log? // {}
          | to_entries[]?
          | emit("smartctl_device_self_test_log_count"; [["device", $device], ["self_test_log_type", .key]]; .value.count)
        ),

        ($j.ata_smart_self_test_log? // {}
          | to_entries[]?
          | emit("smartctl_device_self_test_log_error_count"; [["device", $device], ["self_test_log_type", .key]]; .value.error_count_total)
        ),

        ($j.ata_sct_erc? // {}
          | to_entries[]?
          | emit("smartctl_device_erc_seconds"; [["device", $device], ["op_type", .key]]; n(.value.deciseconds) / 10.0)
        ),

        (if $interface == "nvme" then
          emit("smartctl_device_percentage_used"; [["device", $device]]; $j.nvme_smart_health_information_log.percentage_used),
          emit("smartctl_device_available_spare"; [["device", $device]]; $j.nvme_smart_health_information_log.available_spare),
          emit("smartctl_device_available_spare_threshold"; [["device", $device]]; $j.nvme_smart_health_information_log.available_spare_threshold),
          emit("smartctl_device_critical_warning"; [["device", $device]]; $j.nvme_smart_health_information_log.critical_warning),
          emit("smartctl_device_media_errors"; [["device", $device]]; $j.nvme_smart_health_information_log.media_errors),
          emit("smartctl_device_num_err_log_entries"; [["device", $device]]; $j.nvme_smart_health_information_log.num_err_log_entries),
          (if $j.nvme_smart_health_information_log.data_units_read != null and n($j.nvme_smart_health_information_log.data_units_read) != 0 then
            emit("smartctl_device_bytes_read"; [["device", $device]]; n($j.nvme_smart_health_information_log.data_units_read) * 1000 * 512)
           else empty end),
          (if $j.nvme_smart_health_information_log.data_units_written != null and n($j.nvme_smart_health_information_log.data_units_written) != 0 then
            emit("smartctl_device_bytes_written"; [["device", $device]]; n($j.nvme_smart_health_information_log.data_units_written) * 1000 * 512)
           else empty end)
         else empty end),

        (if $interface == "scsi" then
          emit_if_exists("smartctl_scsi_grown_defect_list"; [["device", $device]]; $j.scsi_grown_defect_list),
          (if $j.scsi_error_counter_log != null then
            emit("smartctl_device_bytes_read"; [["device", $device]]; n($j.scsi_error_counter_log.read.gigabytes_processed) * 1000000000),
            emit("smartctl_device_bytes_written"; [["device", $device]]; n($j.scsi_error_counter_log.write.gigabytes_processed) * 1000000000),
            emit("smartctl_read_errors_corrected_by_rereads_rewrites"; [["device", $device]]; $j.scsi_error_counter_log.read.errors_corrected_by_rereads_rewrites),
            emit("smartctl_read_errors_corrected_by_eccfast"; [["device", $device]]; $j.scsi_error_counter_log.read.errors_corrected_by_eccfast),
            emit("smartctl_read_errors_corrected_by_eccdelayed"; [["device", $device]]; $j.scsi_error_counter_log.read.errors_corrected_by_eccdelayed),
            emit("smartctl_read_total_uncorrected_errors"; [["device", $device]]; $j.scsi_error_counter_log.read.total_uncorrected_errors),
            emit("smartctl_write_errors_corrected_by_rereads_rewrites"; [["device", $device]]; $j.scsi_error_counter_log.write.errors_corrected_by_rereads_rewrites),
            emit("smartctl_write_errors_corrected_by_eccfast"; [["device", $device]]; $j.scsi_error_counter_log.write.errors_corrected_by_eccfast),
            emit("smartctl_write_errors_corrected_by_eccdelayed"; [["device", $device]]; $j.scsi_error_counter_log.write.errors_corrected_by_eccdelayed),
            emit("smartctl_write_total_uncorrected_errors"; [["device", $device]]; $j.scsi_error_counter_log.write.total_uncorrected_errors)
           else empty end)
         else empty end)
      ]
    | .[]
  '
}

write_header > "$tmp"

version_emitted=0
device_count=0

while IFS= read -r dev; do
  json="$("$smartctl_bin" -a -j "$dev" 2>/dev/null || true)"

  printf '%s' "$json" | jq -e . >/dev/null 2>&1 || continue

  if [ "$version_emitted" -eq 0 ]; then
    printf '%s' "$json" | emit_version >> "$tmp"
    version_emitted=1
  fi

  if printf '%s' "$json" | emit_metrics >> "$tmp"; then
    device_count=$((device_count + 1))
  fi
done < <(discover_devices)

printf 'smartctl_devices %s\n' "$device_count" >> "$tmp"

chmod 0644 "$tmp"
mv "$tmp" "$out"
trap - EXIT
