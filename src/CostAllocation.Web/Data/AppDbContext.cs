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
    public DbSet<Servicio> Servicios => Set<Servicio>();
    public DbSet<ServicioPlan> ServicioPlanes => Set<ServicioPlan>();
    public DbSet<ServicioPlanCaracteristica> ServicioPlanCaracteristicas => Set<ServicioPlanCaracteristica>();
    public DbSet<UnidadServicioPlan> UnidadServicioPlanes => Set<UnidadServicioPlan>();

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

        modelBuilder.Entity<Servicio>(e =>
        {
            e.ToTable("Servicios");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Agrupacion)
                .WithMany(a => a.Servicios)
                .HasForeignKey(x => x.AgrupacionId);
        });

        modelBuilder.Entity<ServicioPlan>(e =>
        {
            e.ToTable("ServicioPlanes");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Servicio)
                .WithMany(s => s.Planes)
                .HasForeignKey(x => x.ServicioId);
        });

        modelBuilder.Entity<ServicioPlanCaracteristica>(e =>
        {
            e.ToTable("ServicioPlanCaracteristicas");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Plan)
                .WithMany(p => p.Caracteristicas)
                .HasForeignKey(x => x.PlanId);
        });

        modelBuilder.Entity<UnidadServicioPlan>(e =>
        {
            e.ToTable("UnidadServicioPlanes");
            e.HasKey(x => x.Id);
            e.HasOne(x => x.Unidad)
                .WithMany(u => u.Suscripciones)
                .HasForeignKey(x => x.UnidadId);
            e.HasOne(x => x.Plan)
                .WithMany()
                .HasForeignKey(x => x.PlanId);
        });
    }
}
