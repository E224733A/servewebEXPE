using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Application.Administration;
using MobileSLI.Expedition.Web.Application.Expedition;
using MobileSLI.Expedition.Web.Background;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

builder.Services.Configure<ExpeditionApiOptions>(builder.Configuration.GetSection(ExpeditionApiOptions.SectionName));
builder.Services.Configure<ExpeditionDbOptions>(builder.Configuration.GetSection(ExpeditionDbOptions.SectionName));
builder.Services.Configure<VerrouillageOptions>(builder.Configuration.GetSection(VerrouillageOptions.SectionName));
builder.Services.Configure<AccessControlOptions>(builder.Configuration.GetSection(AccessControlOptions.SectionName));

builder.Services.AddSingleton<IExpeditionDraftStore, SqliteExpeditionDraftStore>();
builder.Services.AddScoped<ExpeditionPreparationViewModelBuilder>();
builder.Services.AddScoped<AdministrationViewModelBuilder>();
builder.Services.AddScoped<VerrouillageService>();

// Version finale : le client web utilise toujours l'API centrale réelle.
// Le FakeExpeditionApiClient peut rester dans le dépôt pour des tests isolés,
// mais il n'est plus enregistré par l'application.
builder.Services.AddHttpClient<IExpeditionApiClient, ExpeditionApiClient>();

builder.Services.AddHostedService<ExpeditionStartupService>();
builder.Services.AddHostedService<VerrouillageBackgroundService>();

var app = builder.Build();

ValidateRuntimeConfiguration(app);

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

// Routage par nom DNS public de l'interface.
// Objectif : permettre aux utilisateurs d'utiliser uniquement :
// - http://expedition.sli.local
// - http://admin.sli.local
// Le port 5100 reste disponible pour le diagnostic technique, mais ne doit plus être l'URL communiquée aux utilisateurs.
app.Use(async (context, next) =>
{
    var host = context.Request.Host.Host;
    var path = context.Request.Path;

    if (host.Equals("admin.sli.local", StringComparison.OrdinalIgnoreCase))
    {
        if (path == "/" || path == PathString.Empty)
        {
            context.Request.Path = "/administration";
        }
        else if (path.StartsWithSegments("/expedition"))
        {
            context.Response.Redirect("/administration", permanent: false);
            return;
        }
    }
    else if (host.Equals("expedition.sli.local", StringComparison.OrdinalIgnoreCase))
    {
        if (path == "/" || path == PathString.Empty)
        {
            context.Request.Path = "/expedition";
        }
        else if (path.StartsWithSegments("/administration"))
        {
            context.Response.Redirect("/expedition", permanent: false);
            return;
        }
    }

    await next();
});

app.UseRouting();

app.Use(async (context, next) =>
{
    ApplySecurityHeaders(context);

    var access = context.RequestServices.GetRequiredService<IOptions<AccessControlOptions>>().Value;
    if (access.Enabled)
    {
        if (access.RequireHttps && !app.Environment.IsDevelopment() && !context.Request.IsHttps)
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync("Accès refusé : HTTPS obligatoire.");
            return;
        }

        if (access.BlockMobileUserAgents && IsMobileUserAgent(context.Request.Headers.UserAgent.ToString()))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync("Accès refusé : interface réservée aux postes Expédition.");
            return;
        }

        // Filtrage applicatif volontairement léger.
        // La restriction réseau principale doit être faite au pare-feu Windows / IIS.
        if (access.AllowedIpPrefixes.Count > 0 && !IsAllowedRemoteAddress(context, access.AllowedIpPrefixes))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync("Accès refusé : poste non autorisé.");
            return;
        }
    }

    await next();
});

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Expedition}/{action=Index}/{id?}");

app.Run();

static void ValidateRuntimeConfiguration(WebApplication app)
{
    var api = app.Services.GetRequiredService<IOptions<ExpeditionApiOptions>>().Value;
    var access = app.Services.GetRequiredService<IOptions<AccessControlOptions>>().Value;

    if (string.IsNullOrWhiteSpace(api.BaseUrl))
    {
        throw new InvalidOperationException("Configuration manquante : ExpeditionApi:BaseUrl doit pointer vers l'API centrale réelle.");
    }

    if (!Uri.TryCreate(api.BaseUrl, UriKind.Absolute, out var apiUri))
    {
        throw new InvalidOperationException("Configuration invalide : ExpeditionApi:BaseUrl doit être une URL absolue.");
    }

    if (!app.Environment.IsDevelopment() && api.UseFakeApi)
    {
        throw new InvalidOperationException("Sécurité : UseFakeApi=true est interdit hors environnement Development.");
    }

    if (!app.Environment.IsDevelopment() && api.RequireHttps && apiUri.Scheme != Uri.UriSchemeHttps)
    {
        throw new InvalidOperationException("Sécurité : l'URL de l'API centrale doit être en HTTPS en production. Désactive explicitement ExpeditionApi:RequireHttps uniquement pour un réseau interne validé.");
    }

    if (!app.Environment.IsDevelopment() && access.RequireIpAllowListInProduction && access.AllowedIpPrefixes.Count == 0)
    {
        throw new InvalidOperationException("Sécurité : AccessControl:AllowedIpPrefixes doit contenir au moins un préfixe IP autorisé en production.");
    }
}

static void ApplySecurityHeaders(HttpContext context)
{
    var headers = context.Response.Headers;

    headers["X-Content-Type-Options"] = "nosniff";
    headers["X-Frame-Options"] = "DENY";
    headers["Referrer-Policy"] = "no-referrer";
    headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    headers["Content-Security-Policy"] = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'";
}

static bool IsMobileUserAgent(string userAgent)
{
    if (string.IsNullOrWhiteSpace(userAgent))
    {
        return false;
    }

    var mobileMarkers = new[]
    {
        "Android",
        "iPhone",
        "iPad",
        "iPod",
        "Windows Phone",
        "Mobile",
        "Mobi"
    };

    return mobileMarkers.Any(marker => userAgent.Contains(marker, StringComparison.OrdinalIgnoreCase));
}

static bool IsAllowedRemoteAddress(HttpContext context, IReadOnlyList<string> allowedIpPrefixes)
{
    var remoteIp = context.Connection.RemoteIpAddress?.ToString();
    if (string.IsNullOrWhiteSpace(remoteIp))
    {
        return false;
    }

    return allowedIpPrefixes.Any(prefix =>
        !string.IsNullOrWhiteSpace(prefix)
        && remoteIp.StartsWith(prefix.Trim(), StringComparison.OrdinalIgnoreCase));
}
