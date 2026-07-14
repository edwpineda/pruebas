namespace CostAllocation.Web.Models;

public class Agrupacion
{
    public long Id { get; set; }
    public int TipoAgrupacionId { get; set; }
    public TipoAgrupacion? TipoAgrupacion { get; set; }
    public string Nombre { get; set; } = "";
    public string? IdentificacionFiscal { get; set; }
    public string Moneda { get; set; } = "USD";
    public string? Direccion { get; set; }
    public byte DiaCorteFacturacion { get; set; } = 1;
    public decimal TasaInteresMora { get; set; }
    public string? Configuracion { get; set; }
    public bool Activo { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }

    public ICollection<Unidad> Unidades { get; set; } = new List<Unidad>();
}
