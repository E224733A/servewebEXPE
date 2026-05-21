Scripts IIS SERVWEB - version corrigee v4

Corrections appliquees :
1. Correction icacls AppPool identity.
2. Correction web.config sous configuration/location/system.webServer.
3. Correction PID 4 / System :
   - avec IIS, le port HTTP peut etre possede par HTTP.sys, visible comme PID 4 System ;
   - c'est normal ;
   - le script ne tente plus de faire Stop-Process sur PID 4 ;
   - IIS est gere proprement par Stop-Website et Stop-WebAppPool.

Contexte :
- SERVWEB = 192.168.1.232
- Port web SERVWEB = 5100
- API = 192.168.1.233:5000
- BaseUrl API = http://192.168.1.233:5000/
- Depot Git = C:\Sources\servewebEXPE

Execution :
1. Remplacer les anciens scripts dans C:\Sources\servewebEXPE\scriptsdeploy.
2. Ouvrir PowerShell en administrateur.
3. Executer :

Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Sources\servewebEXPE
.\scriptsdeploy\update-servweb-iis.ps1

Si besoin de refaire la configuration initiale :
.\scriptsdeploy\setup-servweb-iis.ps1
