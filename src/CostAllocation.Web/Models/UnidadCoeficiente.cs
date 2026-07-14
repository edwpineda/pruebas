namespace CostAllocation.Web.Models;

public class UnidadCoeficiente
{
    public long Id { get; set; }
    public long UnidadId { get; set; }
    public Unidad? Unidad { get; set; }
    public decimal Coeficiente { get; set; }
    public DateOnly VigenteDesde { get; set; }
    public DateOnly? VigenteHasta { get; set; }
    public DateTime CreatedAt { get; set; }
}
