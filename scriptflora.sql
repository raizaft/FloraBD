/*
	Projeto Flora 
	
	Rafael Limeira - 20222370020
	Raiza Andrade  - 20222370023
	
*/
--- 2.a.i - Criação do BD 
create database Flora;

create table Cliente
	(codigo serial primary key,
	 cpf char(11) unique,	
	 nome varchar(35) not null,
	 data_nasc date not null,
	 email varchar(35) not null unique,
	 endereco varchar(200) not null,
	 uf char(2) not null
	);
	
	
create table Vendedor
	(codigo serial primary key,
	 cpf char(11) unique,
	 nome varchar(35) not null,
	 data_nasc date not null,
	 email varchar(35) not null unique,
	 salario numeric(15,2) not null,
	 endereco varchar(200)
	);
	

create table Produto
	(codigo serial primary key,
	 nome varchar(35) not null,
	 preco numeric(15,2) not null,
	 qtd_estoque int not null,
	 tipo char(1) not null,
	 tamanho varchar(35),
	 luminosidade varchar(35),
	 validade date
	);
-- checks produto 
alter table Produto
	add constraint chk_tipo check (tipo in ('p', 'i')),
	add constraint chk_p check
	(case when tipo = 'p' then 
	 	validade is null 
	 	and tamanho is not null
	 	and luminosidade is not null
	 else 
	 	tamanho is null 
	 	and luminosidade is null 
	 end);
	 
	 
create table Pedido
	(num_pedido serial primary key,
	 data_pedido date not null,
	 forma_pgto varchar(45) not null,
	 cod_cli int not null,
	 cod_vend int
	);
alter table Pedido 
	add constraint fk_cliente foreign key(cod_cli) references Cliente(codigo),
	add constraint fk_vendedor foreign key(cod_vend) references Vendedor(codigo);

	
create table Itens_Pedido
	(num_pedido int,
	 cod_produto int, 
	 quantidade int not null
	);
alter table Itens_pedido
	add constraint pk_itens_pedido primary key(num_pedido, cod_produto),
	add constraint fk_pedido foreign key(num_pedido) references Pedido(num_pedido),
	add constraint fk_produto foreign key(cod_produto) references Produto(codigo);


create table Entrega
	(cod_entrega serial, 
	 num_pedido int not null,
	 data_entrega date,
	 valor numeric(15,2) not null,
	 status varchar(35)
	);
alter table Entrega
	add constraint pk_entrega primary key(cod_entrega, num_pedido),
	add constraint fk_pedido foreign key(num_pedido) references Pedido(num_pedido);

--- 2.a.ii - Consultas

-- Operadores básicos de filtro - Produtos fora da validade 
select nome as "Produto", validade from produto
where validade < CURRENT_DATE;

-- Inner join - Quantidade de clientes com entrega atrasada
select count(*) as "Clientes com entrega atrasada"
from cliente c join pedido p on c.codigo = p.cod_cli
join entrega e on p.num_pedido = e.num_pedido
where e.data_entrega < current_date
and (e.status is null or e.status = 'Atrasado');

-- Inner join - Vendas por forma de pgto.
select Pedido.forma_pgto, sum(Produto.preco * Itens_pedido.quantidade) as total_vendido
from Pedido
join Itens_Pedido on Pedido.num_pedido = Itens_Pedido.num_pedido
join Produto ON Itens_Pedido.cod_produto = Produto.codigo
group by Pedido.forma_pgto
order by Pedido.forma_pgto;

-- Inner join (e left outer) - Média de idade de clientes por produtos
with CompradoresPorProduto as (
    select distinct pr.codigo as cod_produto, c.codigo as cod_cliente, c.data_nasc
    from produto pr
    join itens_Pedido ip on pr.codigo = ip.cod_produto
    join pedido p on ip.num_pedido = p.num_pedido
    join cliente c on p.cod_cli = c.codigo
)
select pr.nome as produto, round(coalesce(avg(extract(year from AGE(CURRENT_DATE, c.data_nasc))), 0),2) as media_idade
from produto pr
left join CompradoresPorProduto c on pr.codigo = c.cod_produto
group by pr.nome
order by pr.nome;

-- Left outer join, Group by e Order by - Clientes e qtd. de pedidos 
SELECT
  Cliente.codigo AS codigo_cliente,
  Cliente.nome AS nome_cliente,
  COUNT(Pedido.num_pedido) AS quantidade_pedidos
FROM
  Cliente
LEFT OUTER JOIN
  Pedido ON Cliente.codigo = Pedido.cod_cli
GROUP BY
  Cliente.codigo, Cliente.nome
ORDER BY
  Cliente.codigo;

-- Group by - Quantos clientes compraram cada produto
select pr.nome, count(*) from cliente c
join pedido p on c.codigo = p.cod_cli
join itens_pedido i on p.num_pedido = i.num_pedido
join produto pr on i.cod_produto = pr.codigo
group by pr.nome;

-- Group by e Order by - quantos clientes por estado
select uf, count(*) from cliente
group by uf
order by uf;

-- Except - Vendedores sem pedidos
select codigo
from vendedor
except
select cod_vend
from pedido;

-- Subqueries - Clientes que fizeram mais que 3 pedidos
SELECT codigo, nome
FROM Cliente
WHERE codigo IN (
  SELECT cod_cli
  FROM Pedido
  GROUP BY cod_cli
  HAVING COUNT(*) > 3
);

-- Subqueries - Clientes que fizeram compras de insumos
SELECT codigo, nome
FROM Cliente
WHERE codigo IN (
  SELECT cod_cli
  FROM Pedido
  WHERE num_pedido IN (
    SELECT num_pedido
    FROM Itens_Pedido
    WHERE cod_produto IN (
      SELECT codigo
      FROM Produto
      WHERE tipo = 'i'
    )
  )
);



--- 2.b - Views

-- Visão que permite inserção - View de produtos que são plantas
create or replace view Plantas (nome, preco, qtd_estoque, tipo, tamanho, luminosidade)
as select nome, preco, qtd_estoque, tipo, tamanho, luminosidade from produto
where tipo = 'p';
-- select * from plantas;

-- Visão robusta (utilizando join) - Entregas por clientes com UF
create or replace view UF_Entrega (cliente, pedido, destino, data_entrega, status)
as select c.nome, p.num_pedido, c.uf, e.data_entrega, e.status
from cliente c join pedido p on c.codigo = p.cod_cli
join entrega e on p.num_pedido = e.num_pedido;
-- select * from uf_entrega;

-- Visão robusta (utilizando join) - View com produto e quantidade por vendedor
create or replace view Vendedor_Produto (vendedor, produto, quantidade)
as select v.nome, pr.nome, i.quantidade
from vendedor v join pedido p on v.codigo = p.cod_vend
join itens_pedido i on p.num_pedido = i.num_pedido
join produto pr on i.cod_produto = pr.codigo
order by v.nome;
-- select * from vendedor_produto;

-- Visão robusta (utilizando join, left join e group by) - View que mostra os pedidos detalhados 
-- Numero do pedido, nome do cliente, data do pedido, valor total dos itens, valor de entrega e valor total
CREATE OR REPLACE VIEW Pedido_Detalhado AS
SELECT
    p.num_pedido,
    c.nome AS nome_cliente,
    p.data_pedido,
    COALESCE(SUM(pr.preco * ip.quantidade), 0) AS valor_pedido,
    COALESCE(e.valor, 0) AS valor_entrega,
    COALESCE(SUM(pr.preco * ip.quantidade) + e.valor, 0) AS valor_total
FROM
    Pedido p
JOIN
    Cliente c ON p.cod_cli = c.codigo
LEFT JOIN
    Itens_Pedido ip ON p.num_pedido = ip.num_pedido
LEFT JOIN
    Produto pr ON ip.cod_produto = pr.codigo
LEFT JOIN
    Entrega e ON p.num_pedido = e.num_pedido
GROUP BY
    p.num_pedido, c.nome, p.data_pedido, e.valor;
select * from pedido_detalhado;

--- 2.c - Índices

CREATE INDEX idx_data_nasc ON Cliente(data_nasc);
-- P/ consulta de idades de clientes por produtos


CREATE INDEX idx_data_entrega ON Entrega(data_entrega);
-- P/ consulta de entregas atrasada


CREATE INDEX idx_validade ON Produto(validade);
-- P/ consulta de produtos fora do prazo de validade

--- 2.d - Reescrita de consultas
-- Reescrita das duas consultas que utilizam subqueries para melhoria de desempenho

-- Clientes que fizeram mais que 3 pedidos
SELECT DISTINCT c.codigo, c.nome
FROM Cliente c
JOIN Pedido p ON c.codigo = p.cod_cli
GROUP BY c.codigo, c.nome
HAVING COUNT(DISTINCT p.num_pedido) > 3;

-- Clientes que fizeram compras de insumos
SELECT DISTINCT c.codigo, c.nome
FROM Cliente c
JOIN Pedido p ON c.codigo = p.cod_cli
JOIN Itens_Pedido ip ON p.num_pedido = ip.num_pedido
JOIN Produto pr ON ip.cod_produto = pr.codigo
WHERE pr.tipo = 'i';


--- 2.e - Funções
-- Utilizando COUNT() - Quantidade de pedidos por mês
create or replace function pedidos_mes()
returns void
as $$
declare
	mes_atual integer;
    quantidade_pedidos bigint;
begin
    for mes_atual in 1..12 LOOP
        select count(*) into quantidade_pedidos
        from pedido
        where extract(month from data_pedido) = mes_atual;
        raise notice 'Mês % -- % pedido(s)', mes_atual, quantidade_pedidos;
    end loop;
end;
$$ language plpgsql;
-- select pedidos_mes();

-- Tratamento de exceção - Inserção de produto, com exceção para tipo diferente de 'p' ou 'i'
create or replace function inserirprod
(nome produto.nome%type,
 preco produto.preco%type,
 qtd_estoque produto.qtd_estoque%type,
 tipo produto.tipo%type,
 tamanho produto.tamanho%type,
 luminosidade produto.luminosidade%type,
 validade produto.validade%type)
returns void
as $$
begin
	if tipo = 'p' then
		insert into produto values (default, nome, preco, qtd_estoque, tipo, tamanho, luminosidade, null);
	elsif tipo = 'i' then
		insert into produto values (default, nome, preco, qtd_estoque, tipo, null, null, validade);
	else
		raise exception 'tipo inválido';
	end if;
	Exception
     When raise_exception THEN
       raise notice 'tipo inválido'; 
end;
$$ language 'plpgsql';

select inserirprod('Tesoura de Jardinagem', 35.00, 10, 'i', NULL, NULL, NULL);
select inserirprod('Jiboia', 20, 16, 'p', 'Médio', 'Meia Sombra', NULL);
select inserirprod('Jiboia', 20, 16, 'f', 'Médio', 'Meia Sombra', NULL);
-- select * from produto;

-- Função - Ranking vendedores por vendas
create or replace function rankingvendedores()
returns table (vendedor varchar(100), valor_vendido numeric(12,2))
as $$
begin
	return query
		select v.nome, sum(pr.preco * i.quantidade) as valor_por_pedido
		from vendedor v join pedido p on v.codigo = p.cod_vend
		join itens_pedido i on p.num_pedido = i.num_pedido
		join produto pr on pr.codigo = i.cod_produto
		group by v.nome
		order by valor_por_pedido desc;
	return;
end;
$$ language 'plpgsql';
-- select rankingvendedores();

-- Função - Faturamento
CREATE OR REPLACE FUNCTION calcular_faturamento(ano_param INT, mes_param INT)
RETURNS NUMERIC AS $$
DECLARE
    total_faturado NUMERIC;
BEGIN
    SELECT COALESCE(SUM(ip.quantidade * p.preco), 0)
    INTO total_faturado
    FROM Pedido ped
    JOIN Itens_Pedido ip ON ped.num_pedido = ip.num_pedido
    JOIN Produto p ON ip.cod_produto = p.codigo
    WHERE EXTRACT(YEAR FROM ped.data_pedido) = ano_param
        AND EXTRACT(MONTH FROM ped.data_pedido) = mes_param;

    RETURN total_faturado;
END;
$$ LANGUAGE plpgsql;
-- select calcular_faturamento(2023, 1)



	
--- 2.f - Triggers

-- Atualiza o estoque a cada inserção de um produto em um pedido 
CREATE OR REPLACE FUNCTION atualizar_estoque()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Produto
    SET qtd_estoque = qtd_estoque - NEW.quantidade
    WHERE codigo = NEW.cod_produto;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_atualizar_estoque
AFTER INSERT ON Itens_Pedido
FOR EACH ROW
EXECUTE FUNCTION atualizar_estoque();

-- Auditoria da tabela Cliente 
-- Criação da tabela
CREATE TABLE Auditoria_Cliente (
    id serial primary key,
    acao varchar(10) not null,
    data_modificacao timestamp not null,
    codigo_cliente integer not null
);

CREATE OR REPLACE FUNCTION auditar_modificacoes_cliente()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Auditoria_Cliente (acao, data_modificacao, codigo_cliente)
    VALUES (TG_OP, CURRENT_TIMESTAMP, NEW.codigo);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_auditar_modificacoes_cliente
AFTER INSERT OR UPDATE OR DELETE ON Cliente
FOR EACH ROW
EXECUTE FUNCTION auditar_modificacoes_cliente();
-- select * from auditoria_cliente;

-- Define o valor de entrega e status da entrega de acordo com a uf
CREATE OR REPLACE FUNCTION definir_entrega()
RETURNS TRIGGER AS $$
DECLARE
    valor_entrega numeric(15,2);
	data_entrega date;
	prazo interval;
	status varchar(35);
	uf_cliente char(2);
BEGIN
	-- Pega o uf do cliente
	SELECT uf INTO uf_cliente FROM Cliente WHERE codigo = NEW.cod_cli;
	-- data do pedido
	data_entrega := NEW.data_pedido;

    CASE uf_cliente
        WHEN 'PB', 'PE', 'RN' THEN
            valor_entrega := 10.00;
			data_entrega := data_entrega + interval '3 days';
        WHEN 'MA','AL', 'CE', 'PI', 'BA', 'SE' THEN
            valor_entrega := 15;
					data_entrega := data_entrega + interval '5 days';
        WHEN 'SP', 'RJ' THEN
            valor_entrega := 15.00;
			data_entrega := data_entrega + interval '7 days';
        ELSE
            valor_entrega := 20.00;
			data_entrega := data_entrega + interval '10 days';
    END CASE;
	
	if data_entrega <= current_date then
		status := 'Entregue';
	else
		status:= 'Pendente';
	end if;
		
    INSERT INTO Entrega (num_pedido, data_entrega, valor, status)
    VALUES (NEW.num_pedido, data_entrega, valor_entrega, status);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_definir_entrega
AFTER INSERT ON Pedido
FOR EACH ROW
EXECUTE FUNCTION definir_entrega();
-- select * from entrega;

--- Inserção dos dados
-- Cliente
INSERT INTO Cliente (cpf, nome, data_nasc, email, endereco, uf)
VALUES 
    ('12345678901', 'João Silva', '1990-01-15', 'joao@email.com', 'Rua A, 123', 'PB'),
    ('98765432109', 'Maria Oliveira', '1985-05-20', 'maria@email.com', 'Avenida B, 456', 'RJ'),
    ('23456789012', 'Pedro Santos', '1993-11-03', 'pedro@email.com', 'Rua C, 789', 'MG'),
    ('34567890123', 'Ana Pereira', '1982-07-08', 'ana@email.com', 'Rua D, 567', 'PB'),
    ('45678901234', 'Carlos Souza', '1995-03-25', 'carlos@email.com', 'Avenida E, 890', 'BA'),
    ('56789012345', 'Camila Lima', '1988-09-12', 'camila@email.com', 'Rua F, 234', 'PE'),
    ('67890123456', 'Lucas Costa', '1991-06-18', 'lucas@email.com', 'Avenida G, 567', 'PB'),
    ('78901234567', 'Amanda Rocha', '1980-12-30', 'amanda@email.com', 'Rua H, 123', 'PE'),
    ('89012345678', 'Ricardo Almeida', '1997-08-07', 'ricardo@email.com', 'Avenida I, 456', 'GO'),
    ('90123456789', 'Fernanda Santos', '1987-04-22', 'fernanda@email.com', 'Rua J, 789', 'DF');
-- select * from cliente

-- Vendedor
INSERT INTO Vendedor (cpf, nome, data_nasc, email, salario, endereco)
VALUES 
    ('32165498701', 'Alexandre Oliveira', '1984-02-10', 'alexandre@email.com', 2500.00, 'Avenida X, 987'),
    ('65498732109', 'Cristiane Silva', '1990-07-05', 'cristiane@email.com', 2800.00, 'Rua Y, 654'),
    ('78965432102', 'Bruno Santos', '1989-12-18', 'bruno@email.com', 3000.00, 'Avenida Z, 321'),
    ('12378945605', 'Mariana Costa', '1995-10-30', 'mariana@email.com', 2200.00, 'Rua W, 876'),
    ('45612378908', 'Eduardo Rocha', '1983-04-15', 'eduardo@email.com', 2700.00, 'Avenida V, 543');
-- select * from vendedor

-- Produto
INSERT INTO Produto (nome, preco, qtd_estoque, tipo, tamanho, luminosidade, validade)
VALUES 
    ('Rosa Vermelha', 25.00, 50, 'p', 'Médio', 'Sol Pleno', NULL),
    ('Orquídea Branca', 35.00, 30, 'p', 'Grande', 'Meia Sombra', NULL),
    ('Lírio Amarelo', 30.00, 40, 'p', 'Pequeno', 'Sol Pleno', NULL),
    ('Cacto Espinho Dourado', 15.00, 80, 'p', 'Pequeno', 'Sol Pleno', NULL),
    ('Suculenta Roseta', 10.00, 100, 'p', 'Médio', 'Sol Pleno', NULL),
    ('Violeta Africana', 18.00, 60, 'p', 'Pequeno', 'Meia Sombra', NULL),
    ('Samambaia Pendente', 22.00, 45, 'p', 'Médio', 'Sombra', NULL),
    ('Fertilizante Universal', 8.00, 20, 'i', NULL, NULL, '2023-11-15'),
    ('Substrato para Orquídeas', 12.00, 15, 'i', NULL, NULL, '2025-06-30'),
    ('Adubo Orgânico', 7.50, 25, 'i', NULL, NULL, '2024-10-15'),
    ('Vaso de Cerâmica Azul', 20.00, 10, 'i', NULL, NULL, NULL),
    ('Pá para Jardinagem', 15.00, 8, 'i', NULL, NULL, NULL);
-- select * from Produto

INSERT INTO Pedido (data_pedido, forma_pgto, cod_cli, cod_vend)
VALUES
('2023-01-10', 'Cartão', 1, 1),
('2023-01-15', 'Boleto', 2, 2),
('2023-04-05', 'Dinheiro', 3, 3),
('2023-06-20', 'Cartão', 4, 2),
('2023-07-12', 'Cartão', 5, null),
('2023-08-25', 'Boleto', 6, null),
('2023-12-05', 'Dinheiro', 7, 5),
('2023-12-10', 'Cartão', 8, 1),
('2023-12-15', 'Boleto', 9, 2),
('2023-12-20', 'Dinheiro', 10, 3);
-- select * from pedido;

-- Itens_Pedido
INSERT INTO Itens_Pedido (num_pedido, cod_produto, quantidade)
VALUES
(1, 1, 3),
(1, 2, 2),
(2, 3, 1),
(3, 5, 2),
(3, 6, 3),
(4, 7, 4),
(4, 8, 1),
(5, 10, 3),
(6, 11, 1),
(7, 1, 1), 
(7, 4, 2),
(7, 7, 3), 
(8, 9, 1),
(8, 2, 2), 
(9, 5, 2),
(9, 8, 1), 
(10, 11, 4);
-- select * from itens_pedido;