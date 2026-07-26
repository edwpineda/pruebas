using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CostAllocation.Web.Pages.Servicios;

[Authorize]
public class BuilderModel : PageModel
{
    private readonly AppDbContext _db;
    public BuilderModel(AppDbContext db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public long ServicioId { get; set; }

    [BindProperty(SupportsGet = true)]
    public long AgrupacionId { get; set; }

    public Servicio? Servicio { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Servicio = await _db.Servicios.FindAsync(ServicioId);
        if (Servicio is null) return RedirectToPage("Index", new { agrupacionId = AgrupacionId });
        return Page();
    }
}
