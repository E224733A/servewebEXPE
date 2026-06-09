Scripts IIS SERVWEB - etat courant

Statut :
Ce fichier de synthese remplace l'ancien rappel v6 qui mentionnait encore le port 5100 et l'API HTTP/IP.

Procedure de reference pour les mises a jour courantes :

    scriptsdeploy\update-servweb-iis-prod.ps1

Etat cible actuel :

    SERVWEB / SRVINTRAWEB1
    Site IIS        = MobileSLI.Expedition.Web
    AppPool IIS     = MobileSLI.Expedition.Web
    URLs utilisateur = http://expedition.sli.local et http://admin.sli.local
    Port Web        = 80
    Endpoint local  = http://localhost/verrouillage/executer
    API centrale    = https://srvapi1.sli.local/
    Depot Git       = C:\Sources\servewebEXPE
    Deploiement     = artefact Release versionne dans Git

Regles importantes :

    - ne pas reutiliser le port 5100 comme solution finale ;
    - ne pas compiler sur SERVWEB pour les mises a jour courantes ;
    - conserver C:\Services\MobileSLI.Expedition.Web\data ;
    - conserver C:\Services\MobileSLI.Expedition.Web\logs ;
    - conserver C:\Services\MobileSLI.Expedition.Web\scripts ;
    - verifier ExpeditionApi__BaseUrl = https://srvapi1.sli.local/ apres deploiement.

Commande de deploiement courant sur SERVWEB, en PowerShell administrateur :

    Set-ExecutionPolicy -Scope Process Bypass -Force
    cd C:\Sources\servewebEXPE
    .\scriptsdeploy\update-servweb-iis-prod.ps1

Scripts historiques :

    scriptsdeploy\setup-servweb-iis.ps1
    scriptsdeploy\update-servweb-iis.ps1

Ces scripts historiques peuvent contenir des references anciennes et ne doivent pas remplacer la procedure production actuelle sans verification.

Documentation de reference :

    docs\03-deploiement\servweb-expedition-production.md
    docs\04-exploitation\diagnostic-et-reprise.md
