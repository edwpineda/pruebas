namespace CostAllocation.Web.Models;

/// <summary>Servicio opcional que una Agrupación ofrece a sus Unidades (TV, comida, hospedaje, etc.).</summary>
public class Servicio
{
    public long Id { get; set; }
    public long AgrupacionId { get; set; }
    public Agrupacion? Agrupacion { get; set; }
    public string Nombre { get; set; } = "";
    public string? Icono { get; set; }
    public int Orden { get; set; }
    public bool Activo { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<ServicioPlan> Planes { get; set; } = new List<ServicioPlan>();
}
