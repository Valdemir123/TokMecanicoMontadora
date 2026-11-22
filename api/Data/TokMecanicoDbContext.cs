using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Data;

public class TokMecanicoDbContext(DbContextOptions<TokMecanicoDbContext> options) : DbContext(options)
{
    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<Veiculo> Veiculos => Set<Veiculo>();
    public DbSet<ItemManutencao> ItensManutencao => Set<ItemManutencao>();
    public DbSet<RegistroKm> RegistrosKm => Set<RegistroKm>();
    public DbSet<Manutencao> Manutencoes => Set<Manutencao>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Usuario>(e =>
        {
            e.Property(u => u.Cpf).HasMaxLength(11).IsRequired();
            e.HasIndex(u => u.Cpf).IsUnique();
            e.Property(u => u.NomeCompleto).HasMaxLength(150).IsRequired();
            e.Property(u => u.Email).HasMaxLength(200);
            e.Property(u => u.Telefone).HasMaxLength(20);
            e.Property(u => u.SenhaHash).HasMaxLength(200).IsRequired();
            e.OwnsOne(u => u.EnderecoResidencial, ConfigurarEndereco);
            e.OwnsOne(u => u.EnderecoTrabalho, ConfigurarEndereco);
            e.HasMany(u => u.Veiculos).WithOne(v => v.Usuario).HasForeignKey(v => v.UsuarioId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Veiculo>(e =>
        {
            e.Property(v => v.Placa).HasMaxLength(7).IsRequired();
            e.HasIndex(v => new { v.UsuarioId, v.Placa }).IsUnique();
            e.Property(v => v.Fabricante).HasMaxLength(60).IsRequired();
            e.Property(v => v.Modelo).HasMaxLength(80).IsRequired();
            e.Property(v => v.Cor).HasMaxLength(40).IsRequired();
            e.HasMany(v => v.Itens).WithOne().HasForeignKey(i => i.VeiculoId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(v => v.RegistrosKm).WithOne().HasForeignKey(r => r.VeiculoId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(v => v.Manutencoes).WithOne().HasForeignKey(m => m.VeiculoId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<ItemManutencao>(e =>
        {
            e.Property(i => i.Nome).HasMaxLength(100).IsRequired();
            e.Property(i => i.CodigoCatalogo).HasMaxLength(40);
            e.Property(i => i.Observacao).HasMaxLength(300);
            e.Ignore(i => i.Personalizado);
        });

        b.Entity<Manutencao>(e =>
        {
            e.Property(m => m.Descricao).HasMaxLength(500);
            e.Property(m => m.Oficina).HasMaxLength(150);
            e.Property(m => m.Valor).HasPrecision(12, 2);
            e.PrimitiveCollection(m => m.ItensIds);
        });
    }

    private static void ConfigurarEndereco<T>(OwnedNavigationBuilder<T, Endereco> e) where T : class
    {
        e.Property(x => x.Cep).HasMaxLength(8);
        e.Property(x => x.Logradouro).HasMaxLength(150);
        e.Property(x => x.Numero).HasMaxLength(20);
        e.Property(x => x.Complemento).HasMaxLength(80);
        e.Property(x => x.Bairro).HasMaxLength(80);
        e.Property(x => x.Cidade).HasMaxLength(80);
        e.Property(x => x.Uf).HasMaxLength(2);
    }
}
