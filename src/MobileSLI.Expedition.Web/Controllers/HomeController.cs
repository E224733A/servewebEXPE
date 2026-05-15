using Microsoft.AspNetCore.Mvc;

namespace MobileSLI.Expedition.Web.Controllers;

public sealed class HomeController : Controller
{
    [HttpGet("/Home/Error")]
    public IActionResult Error()
    {
        return View();
    }
}
