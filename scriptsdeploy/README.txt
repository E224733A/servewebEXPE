Scripts IIS SERVWEB - version corrigee v6

Corrections appliquees :
1. Correction icacls AppPool identity.
2. Correction web.config sous configuration/location/system.webServer.
3. Correction PID 4 / System HTTP.sys.
4. Correction AppPool deja arrete dans Restart-IisSite.
5. Correction supplementaire update-servweb-iis.ps1 :
   - suppression du Stop-WebAppPool direct dans le corps principal ;
   - verification de l'etat de l'AppPool avant tentative d'arret ;
   - un AppPool deja arrete est maintenant considere normal.

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
