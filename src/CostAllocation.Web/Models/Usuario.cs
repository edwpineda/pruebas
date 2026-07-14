namespace CostAllocation.Web.Models;

public class Usuario
{
    public long Id { get; set; }
    public long? AgrupacionId { get; set; }
    public long? PersonaId { get; set; }
    public int RolId { get; set; }
    public Rol? Rol { get; set; }
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public bool Activo { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
