# paperless

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.paperless`
  - Access infra server to create paperless_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER paperless WITH PASSWORD '<redacted>';
CREATE DATABASE paperless_db;
ALTER DATABASE paperless_db OWNER TO paperless;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'paperless.oidc.secret'`
- Save this value in secrets.yaml in `paperless.oidc.secret` and `paperless.oidc.hash`
- Use `client_secret_post`, django encodes the secret value wrong frequently.

### Create session secret value

- Create the secret with `LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32`
  - Save this value in secrets.yaml in `paperless.session_secret`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `paperless.il.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "paperless"
```

## Configuration

### Access to paperless

- https://paperless.ilnmors.com
  - name: il
  - E-mail: il@ilnmors.internal
  - password: `paperless.il.password`

### Oauth configuration

- My Profiles: Connect new social account: Authelia
  - Continue
  - Login with Authelia

### OCR configuration

- Configuration: OCR settings
  - Output Type: pdfa
  - Mode: skip
    - When the archive file has broken ocr text, then conduct replcae command manually
  - Skip archive File: never
  - Deskew: disable (toggle to enable and once more to active disable option)
  - rotate: disable (toggle to enable and once more to active disable option)

## The non-standard pdf file

- Some pdf files doesn't follow the standard, for example korean court or government pdf files.
- Before upload this kind of non-standard pdf files, convert it first.
- This process uses ghostscript and powershell in Windows for console

```PowerShell
# 1. The engine
$gsPath = "C:\Program Files\gs\gs10.07.0\bin\gswin64c.exe"

# 2. new folder which the converted file will be stored
$outputDirName = "converted_pdfs"
$outputDir = Join-Path (Get-Location) $outputDirName
if (!(Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir }

# 3. Find all pdf files
$files = Get-ChildItem -Filter *.pdf

foreach ($file in $files) {
    if ($file.FullName -like "*$outputDirName*") { continue }
    
    $inputPath = $file.FullName
    $outputPath = Join-Path $outputDir $file.Name
    
    Write-Host "convert: $($file.Name)" -ForegroundColor Cyan
    
    $gsArgs = @(
        "-sDEVICE=pdfwrite",
        "-dCompatibilityLevel=1.4",
        "-dPDFSETTINGS=/default",
        "-dNOPAUSE",
        "-dQUIET",
        "-dBATCH",
        "-dNoOutputFonts", # Change all text as image
        "-sOutputFile=$outputPath",
        "$inputPath"
    )
    
    # 실행
    & $gsPath @gsArgs
}

Write-Host "`n[Complete] All file is stored in '$outputDirName'." -ForegroundColor Green
```
