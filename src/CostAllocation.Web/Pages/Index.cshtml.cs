using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CostAllocation.Web.Pages;

[Authorize]
public class IndexModel : PageModel
{
    public IActionResult OnGet() => RedirectToPage("/Agrupaciones/Index");
}
