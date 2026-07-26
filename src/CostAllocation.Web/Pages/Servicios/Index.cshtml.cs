using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Servicios;

[Authorize]
public class IndexModel : PageModel
{
    private readonly AppDbContext _db;
    public IndexModel(AppDbContext db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public long AgrupacionId { get; set; }

    public Agrupacion? Agrupacion { get; set; }
    public List<Servicio> Servicios { get; set; } = new();

    public async Task<IActionResult> OnGetAsync()
    {
        Agrupacion = await _db.Agrupaciones.FindAsync(AgrupacionId);
        if (Agrupacion is null) return RedirectToPage("/Agrupaciones/Index");

        Servicios = await _db.Servicios
            .Where(s => s.AgrupacionId == AgrupacionId)
            .Include(s => s.Planes)
            .OrderBy(s => s.Orden)
            .ToListAsync();

        return Page();
    }

    public async Task<IActionResult> OnPostNuevoAsync(long agrupacionId)
    {
        var agrupacion = await _db.Agrupaciones.FindAsync(agrupacionId);
        if (agrupacion is null) return RedirectToPage("/Agrupaciones/Index");

        var ahora = DateTime.UtcNow;
        var siguienteOrden = await _db.Servicios.Where(s => s.AgrupacionId == agrupacionId).CountAsync();

        var servicio = new Servicio
        {
            AgrupacionId = agrupacionId,
            Nombre = "Nuevo servicio",
            Icono = "🧩",
            Orden = siguienteOrden,
            Activo = true,
            CreatedAt = ahora,
            UpdatedAt = ahora
        };
        _db.Servicios.Add(servicio);
        await _db.SaveChangesAsync();

        var nombresPorDefecto = new[] { "Básico", "Estándar", "Premium" };
        for (var i = 0; i < nombresPorDefecto.Length; i++)
        {
            _db.ServicioPlanes.Add(new ServicioPlan
            {
                ServicioId = servicio.Id,
                Nombre = nombresPorDefecto[i],
                Precio = 0,
                HeredaDeInferior = i > 0,
                Orden = i,
                CreatedAt = ahora,
                UpdatedAt = ahora
            });
        }
        await _db.SaveChangesAsync();

        return RedirectToPage("Builder", new { servicioId = servicio.Id, agrupacionId });
    }

    public async Task<IActionResult> OnPostEliminarAsync(long id, long agrupacionId)
    {
        var servicio = await _db.Servicios
            .Include(s => s.Planes).ThenInclude(p => p.Caracteristicas)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (servicio is not null)
        {
            foreach (var plan in servicio.Planes)
            {
                _db.ServicioPlanCaracteristicas.RemoveRange(plan.Caracteristicas);
            }
            _db.ServicioPlanes.RemoveRange(servicio.Planes);
            _db.Servicios.Remove(servicio);
            await _db.SaveChangesAsync();
        }

        return RedirectToPage("Index", new { agrupacionId });
    }
}
