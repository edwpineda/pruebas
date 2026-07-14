using CostAllocation.Web.Data;
using CostAllocation.Web.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Pages;

public class SetupModel : PageModel
{
    private readonly AppDbContext _db;
    public SetupModel(AppDbContext db) => _db = db;

    public bool YaHayUsuarios { get; set; }

    [BindProperty]
    public string Email { get; set; } = "";

    [BindProperty]
    public string Password { get; set; } = "";

    public string? Error { get; set; }

    public async Task OnGetAsync()
    {
        YaHayUsuarios = await _db.Usuarios.AnyAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (await _db.Usuarios.AnyAsync())
        {
            return RedirectToPage("Login");
        }

        if (string.IsNullOrWhiteSpace(Email) || string.IsNullOrWhiteSpace(Password))
        {
            Error = "Completá el correo y la contraseña.";
            return Page();
        }

        var rol = await _db.Roles.FirstOrDefaultAsync(r => r.Codigo == "ADMIN_PLATAFORMA");
        if (rol is null)
        {
            Error = "No existe el rol ADMIN_PLATAFORMA. Corré primero database/schema.sql (incluye los seeds de catálogos).";
            return Page();
        }

        var usuario = new Usuario
        {
            Email = Email,
            RolId = rol.Id,
            Activo = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        usuario.PasswordHash = new PasswordHasher<Usuario>().HashPassword(usuario, Password);

        _db.Usuarios.Add(usuario);
        await _db.SaveChangesAsync();

        return RedirectToPage("Login");
    }
}
