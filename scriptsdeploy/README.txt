Scripts IIS SERVWEB - version corrigee v3

Corrections appliquees :
1. Correction icacls AppPool identity.
2. Correction web.config :
   - le script cherchait system.webServer directement sous configuration ;
   - le web.config publie par ASP.NET Core le place souvent sous configuration/location/system.webServer ;
   - la v3 gere maintenant les deux cas.

Contexte :
- SERVWEB = 192.168.1.232
- Port web SERVWEB = 5100
- API = 192.168.1.233:5000
- BaseUrl API = http://192.168.1.233:5000/
- Depot Git = C:\Sources\servewebEXPE

Execution :
1. Copier les scripts dans C:\Sources\servewebEXPE\scriptsdeploy en remplacant les anciens.
2. Ouvrir PowerShell en administrateur.
3. Executer :

Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Sources\servewebEXPE\scriptsdeploy
.\setup-servweb-iis.ps1

Pour les mises a jour futures :
.\update-servweb-iis.ps1
