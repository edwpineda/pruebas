using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Unidades;

[Authorize]
public class IndexModel : PageModel
{
    private readonly AppDbContext _db;
    public IndexModel(AppDbContext db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public long AgrupacionId { get; set; }

    public Agrupacion? Agrupacion { get; set; }
    public List<Unidad> Unidades { get; set; } = new();

    public async Task<IActionResult> OnGetAsync()
    {
        Agrupacion = await _db.Agrupaciones.FindAsync(AgrupacionId);
        if (Agrupacion is null) return RedirectToPage("/Agrupaciones/Index");

        Unidades = await _db.Unidades
            .Where(u => u.AgrupacionId == AgrupacionId)
            .OrderBy(u => u.Codigo)
            .ToListAsync();

        return Page();
    }
}
