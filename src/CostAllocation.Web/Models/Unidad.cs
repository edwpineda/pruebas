namespace CostAllocation.Web.Models;

public class Unidad
{
    public long Id { get; set; }
    public long AgrupacionId { get; set; }
    public Agrupacion? Agrupacion { get; set; }
    public string Codigo { get; set; } = "";
    public string TipoUnidad { get; set; } = "";
    public decimal? AreaM2 { get; set; }
    public string Estado { get; set; } = "activo";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }

    public ICollection<UnidadCoeficiente> Coeficientes { get; set; } = new List<UnidadCoeficiente>();
}
