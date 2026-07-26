using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Servicios;

// Sin [Authorize]: la vista es pública (cualquiera puede ver los planes). El botón de pago
// exige sesión iniciada y, si no la hay, redirige a /Login (ver OnPostSuscribirAsync).
public class SuscribirModel : PageModel
{
    private readonly AppDbContext _db;
    public SuscribirModel(AppDbContext db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public long AgrupacionId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Ok { get; set; }

    public Agrupacion? Agrupacion { get; set; }
    public List<Servicio> Servicios { get; set; } = new();
    public List<Unidad> Unidades { get; set; } = new();

    public async Task<IActionResult> OnGetAsync()
    {
        Agrupacion = await _db.Agrupaciones.FindAsync(AgrupacionId);
        if (Agrupacion is null) return RedirectToPage("/Agrupaciones/Index");

        Servicios = await _db.Servicios
            .Where(s => s.AgrupacionId == AgrupacionId && s.Activo)
            .Include(s => s.Planes).ThenInclude(p => p.Caracteristicas)
            .OrderBy(s => s.Orden)
            .ToListAsync();

        Unidades = await _db.Unidades
            .Where(u => u.AgrupacionId == AgrupacionId && u.Estado == "activo")
            .OrderBy(u => u.Codigo)
            .ToListAsync();

        return Page();
    }

    public List<ServicioPlanCaracteristica> GetInherited(List<ServicioPlan> planes, int index)
    {
        var plan = planes[index];
        var acc = new List<ServicioPlanCaracteristica>();
        if (index > 0 && plan.HeredaDeInferior)
        {
            acc.AddRange(GetInherited(planes, index - 1));
        }
        acc.AddRange(plan.Caracteristicas.OrderBy(c => c.Orden));
        return acc;
    }

    public async Task<IActionResult> OnPostSuscribirAsync(long agrupacionId, long unidadId, long planId)
    {
        if (User.Identity?.IsAuthenticated != true)
        {
            var returnUrl = Url.Page("Suscribir", new { agrupacionId });
            return RedirectToPage("/Login", new { returnUrl });
        }

        var unidad = await _db.Unidades.FirstOrDefaultAsync(u => u.Id == unidadId && u.AgrupacionId == agrupacionId);
        var plan = await _db.ServicioPlanes
            .Include(p => p.Servicio)
            .FirstOrDefaultAsync(p => p.Id == planId);

        if (unidad is null || plan is null || plan.Servicio?.AgrupacionId != agrupacionId)
        {
            return RedirectToPage("Suscribir", new { agrupacionId });
        }

        var hoy = DateOnly.FromDateTime(DateTime.UtcNow);

        // cierra cualquier suscripción activa de esa unidad al mismo servicio antes de crear la nueva
        var activas = await _db.UnidadServicioPlanes
            .Include(sp => sp.Plan)
            .Where(sp => sp.UnidadId == unidadId && sp.FechaHasta == null && sp.Plan!.ServicioId == plan.ServicioId)
            .ToListAsync();
        foreach (var activa in activas)
        {
            activa.FechaHasta = hoy;
        }

        _db.UnidadServicioPlanes.Add(new UnidadServicioPlan
        {
            UnidadId = unidadId,
            PlanId = planId,
            FechaDesde = hoy
        });

        await _db.SaveChangesAsync();

        return RedirectToPage("Suscribir", new { agrupacionId, ok = plan.Nombre });
    }
}
