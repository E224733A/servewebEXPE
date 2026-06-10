using Microsoft.AspNetCore.Mvc;

namespace MobileSLI.Expedition.Web.Controllers;

/// <summary>
/// Contrôleur minimal conservé pour la page d'erreur MVC standard.
/// Les routes métier Expédition, Administration et Verrouillage sont portées par leurs contrôleurs dédiés.
/// </summary>
public sealed class HomeController : Controller
{
    [HttpGet("/Home/Error")]
    public IActionResult Error()
    {
        return View();
    }
}