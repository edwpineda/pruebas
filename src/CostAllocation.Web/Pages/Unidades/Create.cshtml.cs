using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CostAllocation.Web.Pages.Unidades;

[Authorize]
public class CreateModel : PageModel
{
    private readonly AppDbContext _db;
    public CreateModel(AppDbContext db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public long AgrupacionId { get; set; }

    [BindProperty]
    public Unidad Unidad { get; set; } = new();

    public Agrupacion? Agrupacion { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Agrupacion = await _db.Agrupaciones.FindAsync(AgrupacionId);
        if (Agrupacion is null) return RedirectToPage("/Agrupaciones/Index");
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        Agrupacion = await _db.Agrupaciones.FindAsync(AgrupacionId);
        if (Agrupacion is null) return RedirectToPage("/Agrupaciones/Index");

        if (string.IsNullOrWhiteSpace(Unidad.Codigo))
        {
            ModelState.AddModelError(nameof(Unidad.Codigo), "El código es obligatorio.");
            return Page();
        }

        Unidad.AgrupacionId = AgrupacionId;
        Unidad.Estado = "activo";
        Unidad.CreatedAt = DateTime.UtcNow;
        Unidad.UpdatedAt = DateTime.UtcNow;

        _db.Unidades.Add(Unidad);
        await _db.SaveChangesAsync();

        return RedirectToPage("Index", new { agrupacionId = AgrupacionId });
    }
}
