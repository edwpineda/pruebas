using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Agrupaciones;

[Authorize]
public class CreateModel : PageModel
{
    private readonly AppDbContext _db;
    public CreateModel(AppDbContext db) => _db = db;

    [BindProperty]
    public Agrupacion Agrupacion { get; set; } = new();

    public List<TipoAgrupacion> Tipos { get; set; } = new();

    public async Task OnGetAsync()
    {
        Tipos = await _db.TiposAgrupacion.OrderBy(t => t.Nombre).ToListAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        Tipos = await _db.TiposAgrupacion.OrderBy(t => t.Nombre).ToListAsync();

        if (string.IsNullOrWhiteSpace(Agrupacion.Nombre))
        {
            ModelState.AddModelError(nameof(Agrupacion.Nombre), "El nombre es obligatorio.");
            return Page();
        }

        Agrupacion.Activo = true;
        Agrupacion.CreatedAt = DateTime.UtcNow;
        Agrupacion.UpdatedAt = DateTime.UtcNow;

        _db.Agrupaciones.Add(Agrupacion);
        await _db.SaveChangesAsync();

        return RedirectToPage("Index");
    }
}
