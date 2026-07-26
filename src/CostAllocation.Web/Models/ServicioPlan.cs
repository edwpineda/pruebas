namespace CostAllocation.Web.Models;

/// <summary>
/// Un plan de un Servicio (ej. Básico/Estándar/Premium). El orden define la jerarquía: si
/// <see cref="HeredaDeInferior"/> está activo, el plan incluye en cascada las características
/// del plan con el <see cref="Orden"/> inmediato anterior dentro del mismo Servicio.
/// </summary>
public class ServicioPlan
{
    public long Id { get; set; }
    public long ServicioId { get; set; }
    public Servicio? Servicio { get; set; }
    public string Nombre { get; set; } = "";
    public decimal Precio { get; set; }
    public bool HeredaDeInferior { get; set; }
    public int Orden { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<ServicioPlanCaracteristica> Caracteristicas { get; set; } = new List<ServicioPlanCaracteristica>();
}
