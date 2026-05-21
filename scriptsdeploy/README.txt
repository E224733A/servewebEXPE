# Scripts IIS SERVWEB

## Contexte

- SERVWEB = 192.168.1.232
- Port web SERVWEB = 5100
- API = 192.168.1.233:5000
- BaseUrl API = http://192.168.1.233:5000/
- Depot Git = C:\Sources\servewebEXPE
- Securite reseau principale = pare-feu Windows / IIS

## Pourquoi ces scripts

Il ne faut pas coller les blocs PowerShell morceau par morceau dans la console.
Sinon PowerShell execute le `if` avant que le `else` soit colle, ce qui provoque l'erreur :

else : Le terme «else» n'est pas reconnu

Il faut enregistrer les scripts en `.ps1`, puis les executer.

## Ordre d'execution

1. Ouvrir PowerShell en administrateur.
2. Autoriser l'execution pour la session courante :

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

3. Lancer la configuration initiale :

```powershell
.\setup-servweb-iis.ps1
```

Si le script demande de redemarrer ou si WebAdministration reste indisponible :
- redemarrer SERVWEB ;
- rouvrir PowerShell en administrateur ;
- relancer `setup-servweb-iis.ps1`.

4. Pour les mises a jour suivantes :

```powershell
.\update-servweb-iis.ps1
```
