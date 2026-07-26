namespace CostAllocation.Web.Models;

/// <summary>Suscripción de una Unidad a un ServicioPlan. FechaHasta nula = suscripción activa.</summary>
public class UnidadServicioPlan
{
    public long Id { get; set; }
    public long UnidadId { get; set; }
    public Unidad? Unidad { get; set; }
    public long PlanId { get; set; }
    public ServicioPlan? Plan { get; set; }
    public DateOnly FechaDesde { get; set; }
    public DateOnly? FechaHasta { get; set; }
}
