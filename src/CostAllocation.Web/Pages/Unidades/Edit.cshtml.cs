using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CostAllocation.Web.Pages.Unidades;

[Authorize]
public class EditModel : PageModel
{
    private readonly AppDbContext _db;
    public EditModel(AppDbContext db) => _db = db;

    [BindProperty]
    public Unidad Unidad { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(long id)
    {
        var u = await _db.Unidades.FindAsync(id);
        if (u is null) return RedirectToPage("/Agrupaciones/Index");
        Unidad = u;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var u = await _db.Unidades.FindAsync(Unidad.Id);
        if (u is null) return RedirectToPage("/Agrupaciones/Index");

        u.Codigo = Unidad.Codigo;
        u.TipoUnidad = Unidad.TipoUnidad;
        u.AreaM2 = Unidad.AreaM2;
        u.Estado = Unidad.Estado;
        u.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return RedirectToPage("Index", new { agrupacionId = u.AgrupacionId });
    }
}
