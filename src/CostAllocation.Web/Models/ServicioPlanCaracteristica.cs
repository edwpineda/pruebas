namespace CostAllocation.Web.Models;

public class ServicioPlanCaracteristica
{
    public long Id { get; set; }
    public long PlanId { get; set; }
    public ServicioPlan? Plan { get; set; }
    public string Texto { get; set; } = "";
    public int Orden { get; set; }
}
