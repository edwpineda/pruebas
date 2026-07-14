using CostAllocation.Web.Models;
using Microsoft.EntityFrameworkCore;

namespace CostAllocation.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<TipoAgrupacion> TiposAgrupacion => Set<TipoAgrupacion>();
    public DbSet<Agrupacion> Agrupaciones => Set<Agrupacion>();
    public DbSet<Unidad> Unidades => Set<Unidad>();
    public DbSet<UnidadCoeficiente> UnidadCoeficientes => Set<UnidadCoeficiente>();
    public DbSet<Rol> Roles => Set<Rol>();
    public DbSet<Usuario> Usuarios => Set<Usuario>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TipoAgrupacion>(e =>
        {
            e.ToTable("TiposAgrupacion");
            e.HasKey(x => x.Id);
        });

        modelBuilder.Entity<Agrupacion>(e =>
        {
            e.ToTable("Agrupaciones");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.TipoAgrupacion)
                .WithMany()
                .HasForeignKey(x => x.TipoAgrupacionId);
        });

        modelBuilder.Entity<Unidad>(e =>
        {
            e.ToTable("Unidades");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Agrupacion)
                .WithMany(a => a.Unidades)
                .HasForeignKey(x => x.AgrupacionId);
        });

        modelBuilder.Entity<UnidadCoeficiente>(e =>
        {
            e.ToTable("UnidadCoeficientes");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Unidad)
                .WithMany(u => u.Coeficientes)
                .HasForeignKey(x => x.UnidadId);
        });

        modelBuilder.Entity<Rol>(e =>
        {
            e.ToTable("Roles");
            e.HasKey(x => x.Id);
        });

        modelBuilder.Entity<Usuario>(e =>
        {
            e.ToTable("Usuarios");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Rol)
                .WithMany()
                .HasForeignKey(x => x.RolId);
        });
    }
}
