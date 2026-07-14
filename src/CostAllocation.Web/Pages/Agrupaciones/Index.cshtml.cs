using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages.Agrupaciones;

[Authorize]
public class IndexModel : PageModel
{
    private readonly AppDbContext _db;
    public IndexModel(AppDbContext db) => _db = db;

    public List<Agrupacion> Agrupaciones { get; set; } = new();

    public async Task OnGetAsync()
    {
        Agrupaciones = await _db.Agrupaciones
            .Include(a => a.TipoAgrupacion)
            .OrderBy(a => a.Nombre)
            .ToListAsync();
    }
}
