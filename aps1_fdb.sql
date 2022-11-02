create database pdv_fdb_database;
use pdv_fdb_database;


CREATE TABLE IF NOT EXISTS usuario (
    codigo INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(255) NOT NULL,
    telefone VARCHAR(50) NOT NULL,
    cidade VARCHAR(100),
    bairro VARCHAR(100),
    rua VARCHAR(100),
    numero_casa INT,
    uf VARCHAR(5),
    isAtivo INT NOT NULL DEFAULT 1
);

INSERT INTO
	usuario(nome, telefone, cidade, bairro, rua, numero_casa, uf, isAtivo) 
VALUES 
	("Wilson Costa", "(85) 98888-8888", "Fortaleza", "Alvaro Legal", "Frederico Legal", 82, "CE", 1),
	("Luis Ricardo", "(85) 2222-2222", "Fortaleza", "Carleio", "Omar Barroso", 23, "CE", 1),
    ("Carlos Enrique", "93848-8448", "Copacabana", "Bairro de copacabana", "Rua de copacabana", 43, "RJ", 1)
;

SELECT  
	codigo, nome, telefone, cidade, bairro, rua, numero_casa, uf, isAtivo
FROM usuario
;

UPDATE usuario 
SET 
    isAtivo = 0
WHERE
    uf = "RJ";
    
SELECT 
    nome, uf
FROM
    usuario
WHERE
    isAtivo = 1;
    
CREATE TABLE IF NOT EXISTS cliente (
    codigo INT NOT NULL,
    limite_credito DEC(10 , 2 ) NOT NULL,
    FOREIGN KEY (codigo)
        REFERENCES usuario (codigo)
        ON DELETE CASCADE
);

INSERT INTO cliente(codigo, limite_credito) VALUES (2, 1000.20);

SELECT
	usu.codigo, usu.nome, cli.limite_credito
FROM usuario usu
INNER JOIN cliente cli on cli.codigo = usu.codigo;

CREATE TABLE IF NOT EXISTS funcionario (
    codigo INT NOT NULL,
    funcao varchar(255) NOT NULL,
    FOREIGN KEY (codigo)
        REFERENCES usuario (codigo)
        ON DELETE CASCADE
);

INSERT INTO funcionario(codigo, funcao) VALUES (1, "Gerente de nível atendimento"), (2, "Gerente de nível produtos"), (3, "Garçom");

SELECT
	usu.codigo, usu.nome, usu.telefone, usu.cidade, usu.bairro, func.funcao
FROM usuario usu
INNER JOIN funcionario func on func.codigo = func.codigo;


CREATE TABLE IF NOT EXISTS categoria (
	codigo INT PRIMARY KEY auto_increment NOT NULL,
	descricao varchar(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS produto (
    codigo INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
    cod_categoria INT NOT NULL,
    preco DEC(10 , 2 ) NOT NULL,
    nome VARCHAR(255) NOT NULL,
    FOREIGN KEY (cod_categoria)
        REFERENCES categoria (codigo)
        ON DELETE CASCADE
);


INSERT INTO produto(cod_categoria, preco, nome) values (1, 5.10, "Suco de Goiaba"), (6, 3.00, "Pastel de Frango");

SELECT produto.*, categoria.descricao FROM produto join categoria on produto.cod_categoria = categoria.codigo;

CREATE TABLE IF NOT EXISTS estoque (
    codigo_produto INT NOT NULL,
    usuario_alteracao INT NOT NULL,
    data_alteracao TIMESTAMP NOT NULL,
    quantidade INT NOT NULL,
    PRIMARY KEY (codigo_produto , usuario_alteracao),
    FOREIGN KEY (codigo_produto)
        REFERENCES produto (codigo)
        ON DELETE CASCADE,
    FOREIGN KEY (usuario_alteracaO)
        REFERENCES funcionario (codigo)
        ON DELETE CASCADE
);

INSERT INTO estoque(codigo_produto, usuario_alteracao, data_alteracao, quantidade) values
(1, 1, current_timestamp(), 10),
(2, 1, current_timestamp(), 2)
;

CREATE TABLE IF NOT EXISTS pedido (
    numero INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
    data_elaboracao TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS pedidos_cliente (
    numero_pedido INT,
    codigo_cliente INT,
    FOREIGN KEY (numero_pedido)
        REFERENCES pedido (numero)
        ON DELETE SET NULL,
    FOREIGN KEY (codigo_cliente)
        REFERENCES cliente (codigo)
        ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS pedidos_produtos (
    numero_pedido INT,
    codigo_produto INT,
    quantidade INT NOT NULL,
    FOREIGN KEY (numero_pedido)
        REFERENCES pedido (numero)
        ON DELETE SET NULL,
    FOREIGN KEY (codigo_produto)
        REFERENCES produto (codigo)
);

SELECT 
    prod.codigo,
    prod.preco,
    prod.nome,
    cat.descricao,
    est.quantidade,
    est.usuario_alteracao,
    est.data_alteracao
FROM
    produto prod
	JOIN estoque est ON est.codigo_produto = prod.codigo
    JOIN categoria cat ON cat.codigo = prod.cod_categoria
;

drop procedure if exists criar_pedido;
drop procedure if exists criar_produto_pedido;

delimiter #

CREATE PROCEDURE criar_produto_pedido(pedido int, produto int, quantidade int)
BEGIN
	DECLARE quantida_produto_estoque INT DEFAULT 0;
    
    SET quantida_produto_estoque = ( SELECT e.quantidade from estoque e where  e.codigo_produto = produto );
	
    
    IF (quantidade <= quantida_produto_estoque) THEN
		INSERT INTO pedidos_produtos(numero_pedido, codigo_produto, quantidade) VALUES(pedido, produto, quantidade);
        UPDATE estoque e SET e.quantidade = (quantida_produto_estoque-quantidade) WHERE e.codigo_produto = produto ;
     END IF; 
    
END #

CREATE PROCEDURE criar_pedido (id_cliente int, pedido JSON)
BEGIN

	DECLARE produtos_list_done BOOLEAN DEFAULT FALSE;
	DECLARE id_produto, quantidade_produto INT;
	DECLARE ultimo_pedido_criado INT;
	DECLARE produtos_list CURSOR FOR (
		SELECT 
			json_produto.*
		FROM 
		(
		SELECT JSON_EXTRACT( pedido,
				'$.produtos[*]') as lista
		) produtos_json,
		JSON_TABLE (
			(
				produtos_json.lista
			),
			'$[*]' COLUMNS (
			  `id_produto` INT PATH '$.id_produto', 
			  `quantidade_produto` INT PATH '$.quantidade_produto'
			)
		) json_produto
	);
   
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET produtos_list_done = TRUE;

	INSERT INTO pedido(data_elaboracao) VALUES(current_timestamp());
    SET ultimo_pedido_criado = last_insert_id();
    
    INSERT INTO pedidos_cliente(numero_pedido, codigo_cliente) VALUES(ultimo_pedido_criado, id_cliente);
    
	OPEN produtos_list;
		loop_list: LOOP
			FETCH produtos_list INTO id_produto, quantidade_produto;
            IF produtos_list_done THEN
				LEAVE loop_list;
            END IF;
            
            call criar_produto_pedido(ultimo_pedido_criado, id_produto, quantidade_produto);
            
		END LOOP loop_list;
    CLOSE produtos_list;
    
END #

delimiter ;

call criar_pedido(2, '{ "produtos": [{ "id_produto": 1, "quantidade_produto": 2 }, { "id_produto": 2, "quantidade_produto": 2 }] }');

