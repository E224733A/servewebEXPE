using MobileSLI.Expedition.Web.Background;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

builder.Services.Configure<ExpeditionApiOptions>(builder.Configuration.GetSection(ExpeditionApiOptions.SectionName));
builder.Services.Configure<ExpeditionDbOptions>(builder.Configuration.GetSection(ExpeditionDbOptions.SectionName));
builder.Services.Configure<VerrouillageOptions>(builder.Configuration.GetSection(VerrouillageOptions.SectionName));

builder.Services.AddSingleton<IExpeditionDraftStore, SqliteExpeditionDraftStore>();
builder.Services.AddScoped<VerrouillageService>();

var useFakeApi = builder.Configuration.GetValue<bool>($"{ExpeditionApiOptions.SectionName}:UseFakeApi");
if (useFakeApi)
{
    builder.Services.AddSingleton<IExpeditionApiClient, FakeExpeditionApiClient>();
}
else
{
    builder.Services.AddHttpClient<IExpeditionApiClient, ExpeditionApiClient>();
}

builder.Services.AddHostedService<ExpeditionStartupService>();
builder.Services.AddHostedService<VerrouillageBackgroundService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Expedition}/{action=Index}/{id?}");

app.Run();
