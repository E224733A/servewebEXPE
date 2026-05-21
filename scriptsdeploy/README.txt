Scripts IIS SERVWEB - version corrigee

Correction appliquee :
- remplacement de "IIS AppPool\$AppPoolName:(OI)(CI)M"
- par une variable intermediaire $appPoolIdentity
- puis usage de "${appPoolIdentity}:(OI)(CI)M"

Pourquoi :
PowerShell interprete "$AppPoolName:" comme une reference de variable invalide.
La version corrigee evite cette erreur de parsing.

Execution :
1. Copier les scripts dans C:\Sources\servewebEXPE\scriptsdeploy
2. Ouvrir PowerShell en administrateur
3. Executer :

Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Sources\servewebEXPE\scriptsdeploy
.\setup-servweb-iis.ps1

Pour les mises a jour futures :
.\update-servweb-iis.ps1
