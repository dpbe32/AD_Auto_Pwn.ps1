#banner

function banner {

  $banner = @()
  $banner += ''
  $banner += ' 			______                 ___ ______'
  $banner += '			| ___ \               / _ \|  _  \'
  $banner += '			| |_/ /_      ___ __ / /_\ \ | | |'
  $banner += '			|  __/\ \ /\ / / _ \|  _  | | |  |   [by Daniel Prieto]'
  $banner += '			| |    \ V  V /| | | | | | | |/ /'
  $banner += '			\_|     \_/\_/ |_| |_\_| |_/___/'
  $banner += ''
  $banner | foreach-object {
	  Write-Host $_ -ForegroundColor (Get-Random -Input @('Green','Cyan', 'Yellow', 'Gray','white'))
  }
  Start-Sleep -Seconds  3
  Clear-Host
}

# Declaracion de variables
$Global:ADusers = @('dprieto', 'prueba', 'svc')
$Global:ADPasswords = @('Password1','Password2','MYpassword123#')
$Global:ADUserNames = @('Daniel Prieto', 'Prueba', 'svc')


# Panel de ayuda
function helpPanel {
	Write-Output ''
	Write-Host "1. Una vez importado el modulo, ejecuta el comando domainServicesInstallation" -ForegroundColor "yellow"
	Write-Output ''
	Write-Host "2. Tras el primer reinicio, vuelve a ejecutar posteriormente el comando domainServiceInstallation" -ForegroundColor "yellow"
	Write-Output ''
	Write-Host "3. Una vez el equipo quede cofingurado como DC, ejecuta el comando createUsers" -ForegroundColor "yellow"
	Write-Output ''
	Write-Host "4. En funcion del tipo de ataque que quieras desplegar, ejecutar cualquiera de los siguientes comandos:" -ForeGroundColor "yellow"
	Write-Output ''
	Write-Host "	- createKerberoast" -ForeGround "yellow"
	Write-Host "	- createASRepRoast" -ForeGround "yellow"
	Write-Host "	- createSMBRelay"   -ForeGround "yellow"
	Write-Host "	- createDNSAdmins"  -ForeGround "yellow"
	Write-Host "	- createAll"        -ForeGround "yellow"
	Write-Output ''
}

# Instalacion de los servicios de dominio y configuracion del dominio
function domainServicesInstallation {

	banner
	Write-Output ''
	Write-Host "[*] Instalando los servicios de dominio y configurando el dominio" -ForeGroundColor "yellow"
	Write-Output ''

	Add-WindowsFeature RSAT-ADDS
	Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

	Import-Module ServerManager
	Import-Module ADDSDeployment

	$domainName = "danicorp.local" # por aqui hay que poner el nombre de dominio para instalarlo

	Write-Output ''
	Write-Host '[*] Desinstalando Windows Defender' -ForegroundColor "yellow"
	Write-Output ''

	try {
		$defenderOptions = Get-MpComputerStatus

		if([string]::IsNullOrEmpty($defenderOptions)) {
			Write-Host "No se ha encontrado el windows defender corriendo en el servidor: " $env:computername -ForeGroundColor "Green"
		}

		else {
			Write-Host "Windows Defender se encuentra activo en el servidor:" $env:computername -ForeGroundColor "Cyan"
			Write-Output ''
			Write-Host '	¿Se encuentra Windows Defender habilitado?' $defenderOptions.AntivirusEnabled
			Write-Host '    ¿Se encuentra el servicio de Windows Defender habilitado?' $defenderOptions.AMServiceEnabled
			Write-Host '    ¿Se encuentra el Antispyware de Windows Defender habilitado?' $defenderOptions.AntispywareEnabled
			Write-Host '    ¿Se encuentra el componente OnAccessProtection en Windows Defender?' $defenderOptions.OnAccessProtectionEnabled
			Write-Host '    ¿Se encuentra el componente RealTimeProtection en Windows Defender habilitado?' $defenderOptions.RealTimeProtectionEnabled


			Write-Output ''
			Write-Host "[*] Cambiando el nombre de equipo a dc-company" -ForegroundColor "yellow"
			Write-Output ''

			Rename-Computer -NewName "dc-company"

			Write-Output ''
			Write-Host "[V] Nombre de equipo cambiado exitosamente" -ForeGroundColor "green"

			Write-Output ''
			Write-Host "[!] Es probable que tras finalizar, sea necesario reiniciar el equipo para que los cambios tengan efecto" -ForeGroundColor "red"

			Write-Output ''
			Write-Host "[*] Desinstalando Windows-Defender..." -ForeGroundColor "yellow"

			Uninstall-WindowsFeature -Name Windows-Defender

			Write-Output ''
			Write-Host "[V] Windows Defender ha sido desinstalado vamos a reiniciar el equipo" -ForeGroundColor "green"

			Start-Sleep 5

			Restart-Computer

			Start-Sleep -Seconds 10
		}
	}

	Catch {
		Write-Host "[*] El Windows Denfender se encuentra desinstalado en el Servidor: " $env:computername -ForeGroundColor "yellow"
	}

	Write-Output ''
	Write-Host "[*] A continuacion deberas proporcionar la password del usuario Administrador del dominio" -ForeGroundColor "yellow"
	Write-Output ''

	Try { Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\\Windows\\NTDS" -DomainMode "7" -DomainName $domainName -DomainNetbiosName "danicorp" -ForestMode "7" -InstallDns:$true -LogPath "C:\\Windows\\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\\Windows\SYSVOL" -Force:$true } Catch { Restart-Computer }

	Write-Output ''
	Write-Host '[!] Se va a reiniciar el equipo. Deberas iniciar sesion como usuario Administrador de dominio' -ForeGroundColor "red"
	Write-Output ''
}

function createUsers {
	$counter = 0

	Foreach ($user in $ADUsers) {
		Write-Output ''
		Write-Host "[*] Creando usuario $user" -ForeGroundColor "gray"
		Write-Output ''

		$givenName = $ADUserNames[$counter] | %{ $_.Split(' ')[0]; }
		$surName = $ADUserNames[$counter] | %{ $_.Split(' ')[1]; }
		$username = $ADUsers[$counter]
		$userPassword = $ADPasswords[$counter]
		$securepasswd = ConvertTo-SecureString -String $userPassword -AsPlainText -Force

		Try { New-ADUser -Name $ADUsers[$counter] -GivenName $givenName -Surname $surname -SamAccountName $ADUsers[$counter] -AccountPassword $securepasswd -ChangePasswordAtLogon $False -DisplayName $ADUserNames[$counter] -Enabled $True } Catch {  }


		$counter += 1
	}

	Write-Output ''
	Write-Host "[V] Todos los usuarios han sido creados " -ForeGroundColor "green"
	Write-Output ''
}

# Configuracion para el despliegue del kerberoasting attack
function createKerberoast {
		Write-Output ''
		Write-Host "[*] Configurando entorno para hacer posbible el ataque kerberoasting" -ForeGroundColor "yellow"
		Write-Output ''

		net localgroup Administradores danicorp\svc /add
		setspn -s http/danicorp.local:80 svc

		Write-Output ''
		Write-Host "[V] Laboratorio configurado para desplegar el ataque Kerberoast" -ForeGroundColor "green"
		Write-Output ''
}

# Configuracion para el despliegue del ASRepRoast
function createASRepRoast {

	Write-Output ''
	Write-Host "[*] Configurando entorno para hacer posible el ataque ASRepRoast" -ForegroundColor "yellow"
	Write-Output ''

	set-ADAccountControl svc -DoesNotRequirePreAuth $true

	Write-Output ''
    Write-Host "[V] Laboratorio configurado para el ataque ASRepRoast" -ForegroundColor "green"
    Write-Output ''

}

# Configuracion para el despliegue del ataque SMB relay 
function createSMBRelay {

	Write-Output ''
    Write-Host "[*] Configurando entorno para hacer posible el ataque SMB Relay" -ForegroundColor "yellow"
    Write-Output ''

	Set-SmbClientConfiguration -RequireSecuritySignature 0 -EnableSecuritySignature 0 -Confirm -Force

	Write-Output ''
    Write-Host "[V] Laboratorio configurado para el ataque SMB Relay" -ForegroundColor "green"
    Write-Output ''

}

# Configuracion para el despliegue del ataque dnsAdmins
function createDNSAdmins {

	Write-Output ''
    Write-Host "[*] Configurando entorno para hacer posible el ataque dnsAdmins" -ForegroundColor "yellow"
    Write-Output ''

	net localgroup "DnsAdmins" dprieto /add

    Write-Output ''
    Write-Host "[V] Laboratorio configurado para el ataque dnsAdmins" -ForegroundColor "green"
    Write-Output ''

}

# Configurando todos los ataques
function createAll {
	createKerberoast
	createASRepRoast
	createSMBRelay
	createDNSAdmins

}
