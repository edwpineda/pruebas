using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Agrupaciones;

[Authorize]
public class EditModel : PageModel
{
    private readonly AppDbContext _db;
    public EditModel(AppDbContext db) => _db = db;

    [BindProperty]
    public Agrupacion Agrupacion { get; set; } = new();

    public List<TipoAgrupacion> Tipos { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(long id)
    {
        Tipos = await _db.TiposAgrupacion.OrderBy(t => t.Nombre).ToListAsync();
        var ag = await _db.Agrupaciones.FindAsync(id);
        if (ag is null) return RedirectToPage("Index");
        Agrupacion = ag;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        Tipos = await _db.TiposAgrupacion.OrderBy(t => t.Nombre).ToListAsync();

        var ag = await _db.Agrupaciones.FindAsync(Agrupacion.Id);
        if (ag is null) return RedirectToPage("Index");

        ag.Nombre = Agrupacion.Nombre;
        ag.TipoAgrupacionId = Agrupacion.TipoAgrupacionId;
        ag.Moneda = Agrupacion.Moneda;
        ag.DiaCorteFacturacion = Agrupacion.DiaCorteFacturacion;
        ag.TasaInteresMora = Agrupacion.TasaInteresMora;
        ag.Activo = Agrupacion.Activo;
        ag.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return RedirectToPage("Index");
    }
}
