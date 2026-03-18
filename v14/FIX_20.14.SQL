CREATE OR ALTER PROCEDURE SP_RET_TRIBUTO (
    IDEMPRESA INTEGER,
    IDFILIAL INTEGER,
    IDPRODUTO VARCHAR(16),
    TIPOTRIBUTO INTEGER,
    UFORIGEM VARCHAR(2),
    UFDESTINO VARCHAR(2),
    TIPO_OPERACAO INTEGER = 0,
    TIPO_CLIENTE INTEGER = 0,
    CFOP INTEGER = 0)
RETURNS (
    R_UF_DESTINO VARCHAR(2),
    R_UF_ORIGEM VARCHAR(2),
    TRBPRODUTO INTEGER,
    TRBSUBGRUPO INTEGER,
    TRBGRUPO INTEGER,
    TRBPRIORITARIO INTEGER,
    ORIGMERCPRIORITARIO VARCHAR(1),
    CSTPRIORITARIO INTEGER,
    CODCLASERVPRIORITARIO INTEGER,
    ALIQPRIORITARIO DOUBLE PRECISION,
    TIPOTRBPRIORITARIO INTEGER)
AS
DECLARE VARIABLE IDGRUPO INTEGER;
DECLARE VARIABLE IDSUBGRUPO INTEGER;
begin
  --obtem grupo e subgrupo do produto
  select p.id_grupo_produtos, p.id_sub_grupo_produtos
  from produtos p
  join grupo_produtos gp on gp.id_empresa = p.id_empresa
                        and gp.id_grupo_produtos = p.id_grupo_produtos
  join sub_grupo_produtos sg on sg.id_empresa = p.id_empresa
                            and sg.id_sub_grupo_produtos = p.id_sub_grupo_produtos
  where p.id_empresa = :idempresa
    and p.id_produto = :idproduto
  into :idgrupo, :idsubgrupo;
  -- obtem tributo do produto
  /*
        Prioridade 1 = UF Origem e Destino definidos.
        Prioridade 2 = UF Destino definido.
        Prioridade 3 = UF Origem definido
        Prioridade 4 = Nenhuma UF definida.
        ----
        Tabela verdade
        Prioridade|Origem|Destino
        1|True |True
        2|False|True
        3|True |False
        4|False|False
  */
  --Busca do produto.
  select first 1
         coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
         coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
         trb.id_tributo,
         trb.id_tributo,
         trb.orig_mercadoria,
         trb.situacao_tributaria,
         trb.cod_class_servico,
         trb.tipo_tributo,
         te.aliquota_saida
  from produtos p
  --Prioridade 1
  left join tributos_relacionamento tr1 on tr1.id_produto = p.id_produto
                                       and tr1.id_empresa = p.id_empresa
                                       and tr1.id_filial = :idfilial
                                       and tr1.id_grupo_produtos = 0
                                       and tr1.id_sub_grupo_produtos = 0
                                       and coalesce(tr1.id_estado_orig,'') <> ''
                                       and coalesce(tr1.id_estado,'') <> ''
                                       and tr1.id_estado_orig = :uforigem
                                       and tr1.id_estado = :ufdestino
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr1.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 2
  left join tributos_relacionamento tr2 on tr2.id_produto = p.id_produto
                                       and tr2.id_empresa = p.id_empresa
                                       and tr2.id_filial = :idfilial
                                       and tr2.id_grupo_produtos = 0
                                       and tr2.id_sub_grupo_produtos = 0
                                       and coalesce(tr2.id_estado_orig,'') = ''
                                       and tr2.id_estado = :ufdestino
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr2.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 3
  left join tributos_relacionamento tr3 on tr3.id_produto = p.id_produto
                                       and tr3.id_empresa = p.id_empresa
                                       and tr3.id_filial = :idfilial
                                       and tr3.id_grupo_produtos = 0
                                       and tr3.id_sub_grupo_produtos = 0
                                       and tr3.id_estado_orig = :uforigem
                                       and coalesce(tr3.id_estado,'') = ''
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr3.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 4
  left join tributos_relacionamento tr4 on tr4.id_produto = p.id_produto
                                       and tr4.id_empresa = p.id_empresa
                                       and tr4.id_filial = :idfilial
                                       and tr4.id_grupo_produtos = 0
                                       and tr4.id_sub_grupo_produtos = 0
                                       and coalesce(tr4.id_estado,'') = ''
                                       and coalesce(tr4.id_estado_orig,'') = ''
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr4.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Tributo Encontrado
  join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                   and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
  left join tributos_estados te on te.id_tributo = trb.id_tributo
                               and te.id_estado = :ufdestino
                               and te.cfop = :CFOP
                               and te.id_tipo_cliente = :TIPO_CLIENTE
  where p.id_produto = :idproduto
    and p.id_empresa = :idempresa
  order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
  into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbproduto, :origmercprioritario,
       :cstprioritario, codclaservprioritario, tipotrbprioritario, :aliqprioritario;

  if (:trbprioritario is null) then
  begin
    select first 1
           coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
           coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
           trb.id_tributo,
           trb.id_tributo,
           trb.orig_mercadoria,
           trb.situacao_tributaria,
           trb.cod_class_servico,
           trb.tipo_tributo,
           te.aliquota_saida
    from sub_grupo_produtos p
    --Prioridade 1
    left join tributos_relacionamento tr1 on tr1.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr1.id_empresa = p.id_empresa
                                         and tr1.id_filial = :idfilial
                                         and tr1.id_grupo_produtos = 0
                                         and tr1.id_produto = ''
                                         and coalesce(tr1.id_estado_orig,'') <> ''
                                         and coalesce(tr1.id_estado,'') <> ''
                                         and tr1.id_estado_orig = :uforigem
                                         and tr1.id_estado = :ufdestino
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr1.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 2
    left join tributos_relacionamento tr2 on tr2.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr2.id_empresa = p.id_empresa
                                         and tr2.id_filial = :idfilial
                                         and tr2.id_grupo_produtos = 0
                                         and tr2.id_produto = ''
                                         and coalesce(tr2.id_estado_orig,'') = ''
                                         and tr2.id_estado = :ufdestino
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr2.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 3
    left join tributos_relacionamento tr3 on tr3.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr3.id_empresa = p.id_empresa
                                         and tr3.id_filial = :idfilial
                                         and tr3.id_grupo_produtos = 0
                                         and tr3.id_produto = ''
                                         and tr3.id_estado_orig = :uforigem
                                         and coalesce(tr3.id_estado,'') = ''
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr3.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 4
    left join tributos_relacionamento tr4 on tr4.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr4.id_empresa = p.id_empresa
                                         and tr4.id_filial = :idfilial
                                         and tr4.id_grupo_produtos = 0
                                         and tr4.id_produto = ''
                                         and coalesce(tr4.id_estado,'') = ''
                                         and coalesce(tr4.id_estado_orig,'') = ''
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr4.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Tributo Encontrado
    join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                     and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
    left join tributos_estados te on te.id_tributo = trb.id_tributo
                                 and te.id_estado = :ufdestino
                                 and te.cfop = :CFOP
                                 and te.id_tipo_cliente = :TIPO_CLIENTE
    where p.id_sub_grupo_produtos = :idsubgrupo
      and p.id_empresa = :idempresa
    order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
    into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbsubgrupo, :origmercprioritario,
         :cstprioritario, :codclaservprioritario, :tipotrbprioritario, :aliqprioritario;

    if (:trbprioritario is null) then
    begin
      select first 1
             coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
             coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
             trb.id_tributo,
             trb.id_tributo,
             trb.orig_mercadoria,
             trb.situacao_tributaria,
             trb.cod_class_servico,
             trb.tipo_tributo,
             te.aliquota_saida
      from grupo_produtos p
      --Prioridade 1
      left join tributos_relacionamento tr1 on tr1.id_grupo_produtos = p.id_grupo_produtos
                                           and tr1.id_empresa = p.id_empresa
                                           and tr1.id_filial = :idfilial
                                           and tr1.id_sub_grupo_produtos = 0
                                           and tr1.id_produto = ''
                                           and coalesce(tr1.id_estado_orig,'') <> ''
                                           and coalesce(tr1.id_estado,'') <> ''
                                           and tr1.id_estado_orig = :uforigem
                                           and tr1.id_estado = :ufdestino
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr1.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 2
      left join tributos_relacionamento tr2 on tr2.id_grupo_produtos = p.id_grupo_produtos
                                           and tr2.id_empresa = p.id_empresa
                                           and tr2.id_filial = :idfilial
                                           and tr2.id_sub_grupo_produtos = 0
                                           and tr2.id_produto = ''
                                           and coalesce(tr2.id_estado_orig,'') = ''
                                           and tr2.id_estado = :ufdestino
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr2.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 3
      left join tributos_relacionamento tr3 on tr3.id_grupo_produtos = p.id_grupo_produtos
                                           and tr3.id_empresa = p.id_empresa
                                           and tr3.id_filial = :idfilial
                                           and tr3.id_sub_grupo_produtos = 0
                                           and tr3.id_produto = ''
                                           and tr3.id_estado_orig = :uforigem
                                           and coalesce(tr3.id_estado,'') = ''
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr3.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 4
      left join tributos_relacionamento tr4 on tr4.id_grupo_produtos = p.id_grupo_produtos
                                           and tr4.id_empresa = p.id_empresa
                                           and tr4.id_filial = :idfilial
                                           and tr4.id_sub_grupo_produtos = 0
                                           and tr4.id_produto = ''
                                           and coalesce(tr4.id_estado,'') = ''
                                           and coalesce(tr4.id_estado_orig,'') = ''
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr4.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Tributo Encontrado
      join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                       and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
      left join tributos_estados te on te.id_tributo = trb.id_tributo
                                   and te.id_estado = :ufdestino
                                   and te.cfop = :CFOP
                                   and te.id_tipo_cliente = :TIPO_CLIENTE
      where p.id_grupo_produtos = :idgrupo
        and p.id_empresa = :idempresa
      order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
      into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbgrupo, :origmercprioritario,
           :cstprioritario, :codclaservprioritario, :tipotrbprioritario, :aliqprioritario;
    end
  end
  -- retorna valores nulos para os nao encontrados para uso com coalesce()
  trbproduto  = nullif(:trbproduto, 0);
  trbsubgrupo = nullif(:trbsubgrupo, 0);
  trbgrupo    = nullif(:trbgrupo, 0);
  suspend;
end
;

CREATE OR ALTER PROCEDURE SP_RET_TRIBUTO_COMPLEMENTO (
    ID_EMPRESA INTEGER NOT NULL,
    ID_FILIAL INTEGER,
    ID_TRIBUTO INTEGER NOT NULL,
    UF_DESTINO VARCHAR(2) NOT NULL,
    ID_TIPO_CLIENTE INTEGER NOT NULL,
    CFOP INTEGER NOT NULL,
    TIPO_PESSOA VARCHAR(1) NOT NULL,
    TIPOSERIE INTEGER NOT NULL,
    MODELOECF INTEGER)
RETURNS (
    R_ID_TRIBUTO INTEGER,
    R_ID_ESTADO VARCHAR(2),
    R_ID_TIPO_CLIENTE INTEGER,
    R_CFOP INTEGER,
    CST VARCHAR(3),
    AGREGADO DOUBLE PRECISION,
    PCREDSN DOUBLE PRECISION,
    PCTMEDIA DOUBLE PRECISION,
    PRECO_BASE INTEGER,
    ALIQUOTA_SAIDA DOUBLE PRECISION,
    ALIQUOTA_ENTRADA DOUBLE PRECISION,
    CREDITO_ICMS INTEGER,
    CODIGO_ECF VARCHAR(10),
    PFCP DOUBLE PRECISION,
    ORIG_MERCADORIA VARCHAR(1),
    CENQ VARCHAR(3),
    REDUCAO_BASE_IMPORT_DIRETA SMALLINT,
    MENSAGEM_NOTA_POR_ESTADO VARCHAR(1000),
    ALIQUOTA_MSG_CRED_ICMS DOUBLE PRECISION,
    ALIQUOTA_ADREM DOUBLE PRECISION)
AS
DECLARE VARIABLE ALIQUOTA_ECF DOUBLE PRECISION;
begin
  if (coalesce(:uf_destino,'') = '') then
  begin
    select m.id_estado from filiais f
    join bairros b on f.id_bairro = b.id_bairro
    join municipios m on m.id_municipio = b.id_municipio
    where f.id_empresa = :id_empresa
      and f.id_filial = :id_filial
    into :uf_destino;
  end
  select first 1
         te.id_tributo,
         te.id_estado,
         te.id_tipo_cliente,
         te.cfop,
         case when (coalesce(te.cst,"") = '') then trb.situacao_tributaria else te.cst end cst,
         coalesce(te.agregado,0),
         te.pcredsn,
         te.pctmedia,
         te.preco_base,
         case
           when upper(:TIPO_PESSOA) = 'F' then TE.ALIQUOTA_PESS_FISICA
           when upper(:TIPO_PESSOA) = 'G' then TE.ALIQUOTA_GOVERNO
         else TE.ALIQUOTA_SAIDA
         end aliquota_saida,
         te.aliquota_entrada,
         te.credito_icms,
         te.pfcp,
         case when coalesce(te.orig_mercadoria,"") = '' then trb.orig_mercadoria else te.orig_mercadoria end orig_mercadoria,
         te.cenq,
         te.reducao_base_import_direta,
         te.mensagem_nota_por_estado,
         te.aliquota_msg_cred_icms,
         te.aliquota_adrem
  from tributos trb
  join empresas e on e.id_empresa = :id_empresa
  left join tributos_estados p1 on p1.id_tributo = trb.id_tributo
                               and p1.id_estado = :uf_destino
                               and p1.id_tipo_cliente = :id_tipo_cliente
                               and p1.cfop = :cfop
  left join tributos_estados p2 on p2.id_tributo = trb.id_tributo
                               and p2.id_estado = :uf_destino
                               and p2.cfop = 0
                               and p2.id_tipo_cliente = :id_tipo_cliente
  left join tributos_estados p3 on p3.id_tributo = trb.id_tributo
                               and p3.id_estado = :uf_destino
                               and p3.cfop = :cfop
                               and p3.id_tipo_cliente = 0
  left join tributos_estados p4 on p4.id_tributo = trb.id_tributo
                               and p4.id_estado = :uf_destino
                               and p4.cfop = 0
                               and p4.id_tipo_cliente = 0
  join tributos_estados te on te.id_tributo = trb.id_tributo
                          and te.id_estado = :uf_destino
                          and te.cfop = coalesce(p1.cfop, p2.cfop, p3.cfop, p4.cfop)
                          and te.id_tipo_cliente = coalesce(p1.id_tipo_cliente, p2.id_tipo_cliente, p3.id_tipo_cliente, p4.id_tipo_cliente)
  where trb.id_tributo = :id_tributo
    and (te.cfop = :cfop or te.cfop = 0)
  into :r_id_tributo, :r_id_estado, :r_id_tipo_cliente, :r_cfop, :cst, :agregado, pcredsn, :pctmedia, :preco_base, :aliquota_saida, :aliquota_entrada,
       :credito_icms, :pFCP, :orig_mercadoria, :cenq, :reducao_base_import_direta, :mensagem_nota_por_estado, :aliquota_msg_cred_icms, :aliquota_adrem;
  if ((:r_id_tributo is not null) and (coalesce(:modeloecf,0) > 0)) then
  begin
    select first 1
           case
             when upper(coalesce(codigo_ecf,'')) = 'TT' then
               case when :aliquota_saida = 0 then 'F' else 'T'||formatfloat('0000', :aliquota_saida * 100) end
             when (strlen(coalesce(codigo_ecf,'')) >= 1) and (substr(upper(codigo_ecf),1,1) = 'T') then
                case when (:TipoSerie = 1) and (:aliquota_saida = 0) then
                  'T' || formatfloat('0000', 0.01 * 100)
                else
                  'T' || formatfloat('0000', :aliquota_saida * 100)
                end
           end codigo_ecf,
           case when (:TipoSerie = 1) and (:aliquota_saida = 0) then 0.01 else null end aliquota
    from tributos_ecf ecf
    where ecf.id_empresa = :id_empresa
      and ecf.id_tributo = :r_id_tributo
      and ecf.id_modelo_ecf = :modeloecf
    into :codigo_ecf, :aliquota_ecf;
    aliquota_saida = coalesce(:aliquota_ecf, :aliquota_saida);
  end
  suspend;
end
;

CREATE OR ALTER PROCEDURE SP_RET_TRIBUTO_OPERACAO (
    ID_EMPRESA INTEGER NOT NULL,
    ID_FILIAL INTEGER NOT NULL,
    ID_PRODUTO VARCHAR(20) NOT NULL,
    UF_ORIGEM VARCHAR(2) NOT NULL,
    UF_DESTINO VARCHAR(2) NOT NULL,
    TIPO_TRIBUTO INTEGER NOT NULL,
    TIPO_MOVIMENTO INTEGER NOT NULL,
    ID_TIPO_CLIENTE INTEGER NOT NULL,
    CFOP INTEGER NOT NULL,
    TIPO_PESSOA VARCHAR(1) NOT NULL,
    TIPO_SERIE INTEGER,
    MODELO_ECF INTEGER,
    INDIEDEST INTEGER)
RETURNS (
    R_ID_EMPRESA INTEGER,
    R_ID_PRODUTO VARCHAR(15),
    R_ID_TRIBUTO INTEGER,
    R_TIPO_TRIBUTO INTEGER,
    R_DESCRICAO VARCHAR(40),
    R_CST INTEGER,
    R_CFOP INTEGER,
    R_PRIORIDADE INTEGER,
    R_AGREGADO DOUBLE PRECISION,
    R_PCREDSN DOUBLE PRECISION,
    R_PCTMEDIA DOUBLE PRECISION,
    R_CREDITO_ICMS INTEGER,
    R_PRECO_BASE INTEGER,
    R_CODIGO_ECF VARCHAR(10),
    R_ALIQUOTA_ENTRADA DOUBLE PRECISION,
    R_ALIQUOTA_SAIDA DOUBLE PRECISION,
    R_REDUCAO_BASE_CALCULO DOUBLE PRECISION,
    R_PFCP DOUBLE PRECISION,
    R_ORIG_MERCADORIA VARCHAR(1),
    R_CLASS_PRECO INTEGER,
    R_CENQ VARCHAR(3),
    R_REDUCAO_BASE_IMPORT_DIRETA SMALLINT,
    R_TIPO_CALCULO SMALLINT,
    R_MENSAGEM_NOTA_POR_ESTADO VARCHAR(1000),
    R_ALIQUOTA_MSG_CRED_ICMS DOUBLE PRECISION,
    R_ALIQUOTA_ADREM DOUBLE PRECISION)
AS
DECLARE VARIABLE TIPO_OPERACAO INTEGER;
begin
  if (coalesce(:uf_origem,'') = '') then
  begin
    select m.id_estado from filiais f
    join bairros b on f.id_bairro = b.id_bairro
    join municipios m on m.id_municipio = b.id_municipio
    where f.id_empresa = :id_empresa
      and f.id_filial = :id_filial
    into :uf_origem;
  end
  if (coalesce(:uf_destino,'') = '') then
  begin
    select m.id_estado from filiais f
    join bairros b on f.id_bairro = b.id_bairro
    join municipios m on m.id_municipio = b.id_municipio
    where f.id_empresa = :id_empresa
      and f.id_filial = :id_filial
    into :uf_destino;
  end
  indIEDest = coalesce(:indIEDest,0);
  if (coalesce(:tipo_movimento,0) in (1,4,10)) then
    tipo_operacao = 2;
  else if (coalesce(:tipo_movimento,0) in (2,3,9)) then
    tipo_operacao = 1;
  else
    tipo_operacao = 0;
  select first 1
         p.id_empresa, 
         p.id_produto, 
         spt.trbprioritario id_tributo, 
         spt.tipotrbprioritario tipo_tributo, 
         trb.descricao, 
         coalesce(spc.cst, trb.situacao_tributaria) cst,
         case
           when coalesce(:CFOP,0) > 0 then :CFOP
           when :uf_origem = spc.r_id_estado then
             case 
               when :tipo_movimento in (1,7) and trb.cfop_venda_interna > 0 then trb.cfop_venda_interna
               when :tipo_movimento = 3 and trb.cfop_dev_cli_interna > 0then trb.cfop_dev_cli_interna
               when :tipo_movimento = 4 and trb.cfop_dev_interna > 0 then trb.cfop_dev_interna
               when :tipo_movimento = 10 and trb.cfop_transf_interna > 0 then trb.cfop_transf_interna
               when :tipo_movimento = 9 and trb.cfop_transf_ent_interna > 0 then trb.cfop_transf_ent_interna
               when :tipo_movimento in (2,6) and trb.cfop_outros_interna > 0 then trb.cfop_outros_interna
             end 
         else
           case
             when :tipo_movimento in (1,7) and :indIEDest in (2,9) and trb.cfop_venda_externa_n_cont > 0 then trb.cfop_venda_externa_n_cont
             when :tipo_movimento in (1,7) and trb.cfop_venda_externa > 0 then trb.cfop_venda_externa
             when :tipo_movimento = 3 and trb.cfop_dev_cli_externa > 0 then trb.cfop_dev_cli_externa
             when :tipo_movimento = 4 and trb.cfop_dev_externa > 0 then trb.cfop_dev_externa
             when :tipo_movimento = 10 and trb.cfop_transf_externa > 0 then trb.cfop_transf_externa
             when :tipo_movimento =  9 and trb.cfop_transf_ent_externa > 0 then trb.cfop_transf_ent_externa
             when :tipo_movimento in (2,6) and trb.cfop_outros_externa > 0 then trb.cfop_outros_externa
           end
         end cfop,  
         case 
           when coalesce(spt.trbproduto,0) > 0 then 0 
           when coalesce(spt.trbsubgrupo,0) > 0 then 1 
           when coalesce(spt.trbgrupo,0) > 0 then 2 
         end prioridade, 
         coalesce(spc.agregado,0) agregado, 
         spc.pcredsn, 
         spc.pctmedia, 
         spc.credito_icms, 
         spc.preco_base, 
         spc.codigo_ecf, 
         spc.aliquota_entrada, 
         spc.aliquota_saida, 
         trb.reducao_base_calculo,
         spc.pfcp,
         coalesce(spc.orig_mercadoria, trb.orig_mercadoria) orig_mercadoria,
         trb.class_preco,
         spc.cenq,
         case when :tipo_tributo = 1 then spc.reducao_base_import_direta else 2 end, --somente ICMS
         trb.tipo_calculo,
         spc.mensagem_nota_por_estado,
         spc.aliquota_msg_cred_icms,
         spc.aliquota_adrem
  from produtos p
  left join sp_ret_tributo(p.id_empresa, :id_filial, p.id_produto, :tipo_tributo, :uf_origem, :uf_destino, :tipo_operacao,
                           case when cast(:cfop as integer) in (5927) then cast(:id_tipo_cliente as integer)
                                when cast(:tipo_movimento as integer) in (9,10) then cast(:id_tipo_cliente as integer) else null end,
                           case when cast(:cfop as integer) in (5927) then cast(:cfop as integer)
                                when cast(:tipo_movimento as integer) in (9,10) then cast(:cfop as integer) else null end) spt on 1=1
  join tributos trb on trb.id_tributo = spt.trbprioritario
  left join sp_ret_tributo_complemento(p.id_empresa, :id_filial, trb.id_tributo, :uf_destino, :id_tipo_cliente, :cfop, :tipo_pessoa, :tipo_serie, :modelo_ecf) spc on 1=1
  where p.id_produto = :id_produto
    and coalesce(spc.r_id_tributo,0) > 0
    and p.id_empresa = :id_empresa
  into r_id_empresa, r_id_produto, r_id_tributo, r_tipo_tributo, r_descricao, r_cst, r_cfop, r_prioridade, r_agregado, r_pcredsn, r_pctmedia,
       r_credito_icms, r_preco_base, r_codigo_ecf, r_aliquota_entrada, r_aliquota_saida, r_reducao_base_calculo, r_pfcp, r_orig_mercadoria,
       r_class_preco, r_cenq, r_reducao_base_import_direta, r_tipo_calculo, r_mensagem_nota_por_estado, r_aliquota_msg_cred_icms, r_aliquota_adrem;
  suspend;
end
;

create or alter procedure SP_RET_TRIBUTO_OPERACAO (
    ID_EMPRESA integer not null,
    ID_FILIAL integer not null,
    ID_PRODUTO varchar(20) not null,
    UF_ORIGEM varchar(2) not null,
    UF_DESTINO varchar(2) not null,
    TIPO_TRIBUTO integer not null,
    TIPO_MOVIMENTO integer not null,
    ID_TIPO_CLIENTE integer not null,
    CFOP integer not null,
    TIPO_PESSOA varchar(1) not null,
    TIPO_SERIE integer,
    MODELO_ECF integer,
    INDIEDEST integer)
returns (
    R_ID_EMPRESA integer,
    R_ID_PRODUTO varchar(15),
    R_ID_TRIBUTO integer,
    R_TIPO_TRIBUTO integer,
    R_DESCRICAO varchar(40),
    R_CST integer,
    R_CFOP integer,
    R_PRIORIDADE integer,
    R_AGREGADO double precision,
    R_PCREDSN double precision,
    R_PCTMEDIA double precision,
    R_CREDITO_ICMS integer,
    R_PRECO_BASE integer,
    R_CODIGO_ECF varchar(10),
    R_ALIQUOTA_ENTRADA double precision,
    R_ALIQUOTA_SAIDA double precision,
    R_REDUCAO_BASE_CALCULO double precision,
    R_PFCP double precision,
    R_ORIG_MERCADORIA varchar(1),
    R_CLASS_PRECO integer,
    R_CENQ VARCHAR(03),
    R_REDUCAO_BASE_IMPORT_DIRETA smallint,
    R_TIPO_CALCULO smallint,
    R_MENSAGEM_NOTA_POR_ESTADO varchar(1000),
    R_ALIQUOTA_MSG_CRED_ICMS double precision,
    R_ALIQUOTA_ADREM double precision)
as
declare variable TIPO_OPERACAO INTEGER;
begin

  if (coalesce(:uf_origem,'') = '') then
  begin

    select m.id_estado from filiais f
    join bairros b on f.id_bairro = b.id_bairro
    join municipios m on m.id_municipio = b.id_municipio
    where f.id_empresa = :id_empresa
      and f.id_filial = :id_filial
    into :uf_origem;

  end
    
  if (coalesce(:uf_destino,'') = '') then
  begin

    select m.id_estado from filiais f
    join bairros b on f.id_bairro = b.id_bairro
    join municipios m on m.id_municipio = b.id_municipio
    where f.id_empresa = :id_empresa
      and f.id_filial = :id_filial
    into :uf_destino;

  end

  indIEDest = coalesce(:indIEDest,0);

  if (coalesce(:tipo_movimento,0) in (1,4,10)) then
    tipo_operacao = 2;
  else if (coalesce(:tipo_movimento,0) in (2,3,9)) then
    tipo_operacao = 1;
  else
    tipo_operacao = 0;

  select first 1
         p.id_empresa, 
         p.id_produto, 
         spt.trbprioritario id_tributo, 
         spt.tipotrbprioritario tipo_tributo, 
         trb.descricao, 
         coalesce(spc.cst, trb.situacao_tributaria) cst,
         case
           when coalesce(:cfop,0) > 0 then :cfop
           when :uf_origem = spc.r_id_estado then
             case 
               when :tipo_movimento in (1,7) and trb.cfop_venda_interna > 0 then trb.cfop_venda_interna
               when :tipo_movimento = 3 and trb.cfop_dev_cli_interna > 0then trb.cfop_dev_cli_interna
               when :tipo_movimento = 4 and trb.cfop_dev_interna > 0 then trb.cfop_dev_interna
               when :tipo_movimento = 10 and trb.cfop_transf_interna > 0 then trb.cfop_transf_interna
               when :tipo_movimento = 9 and trb.cfop_transf_ent_interna > 0 then trb.cfop_transf_ent_interna
               when :tipo_movimento in (2,6) and trb.cfop_outros_interna > 0 then trb.cfop_outros_interna
             end 
         else
           case
             when :tipo_movimento in (1,7) and :indIEDest in (2,9) and trb.cfop_venda_externa_n_cont > 0 then trb.cfop_venda_externa_n_cont
             when :tipo_movimento in (1,7) and trb.cfop_venda_externa > 0 then trb.cfop_venda_externa
             when :tipo_movimento = 3 and trb.cfop_dev_cli_externa > 0 then trb.cfop_dev_cli_externa
             when :tipo_movimento = 4 and trb.cfop_dev_externa > 0 then trb.cfop_dev_externa
             when :tipo_movimento = 10 and trb.cfop_transf_externa > 0 then trb.cfop_transf_externa
             when :tipo_movimento =  9 and trb.cfop_transf_ent_externa > 0 then trb.cfop_transf_ent_externa
             when :tipo_movimento in (2,6) and trb.cfop_outros_externa > 0 then trb.cfop_outros_externa
           end
         end cfop,  
         case 
           when coalesce(spt.trbproduto,0) > 0 then 0 
           when coalesce(spt.trbsubgrupo,0) > 0 then 1 
           when coalesce(spt.trbgrupo,0) > 0 then 2 
         end prioridade, 
         coalesce(spc.agregado,0) agregado, 
         spc.pcredsn, 
         spc.pctmedia, 
         spc.credito_icms, 
         spc.preco_base, 
         spc.codigo_ecf, 
         spc.aliquota_entrada, 
         spc.aliquota_saida, 
         trb.reducao_base_calculo,
         spc.pfcp,
         coalesce(spc.orig_mercadoria, trb.orig_mercadoria) orig_mercadoria,
         trb.class_preco,
         spc.cenq,
         case when :tipo_tributo = 1 then spc.reducao_base_import_direta else 2 end, --somente ICMS
         trb.tipo_calculo,
         spc.mensagem_nota_por_estado,
         spc.aliquota_msg_cred_icms,
         spc.aliquota_adrem
  from produtos p
  left join sp_ret_tributo(p.id_empresa, :id_filial, p.id_produto, :tipo_tributo, :uf_origem, :uf_destino, :tipo_operacao,
                           case when (:cfop = 5927) then :id_tipo_cliente
                                when (:tipo_movimento in (9,10)) then :id_tipo_cliente else 0 end,
                           case when (:cfop = 5927) then :cfop
                                when (:tipo_movimento in (9,10)) then :cfop else 0 end) spt on 1=1
  join tributos trb on trb.id_tributo = spt.trbprioritario
  left join sp_ret_tributo_complemento(p.id_empresa, :id_filial, trb.id_tributo, :uf_destino, :id_tipo_cliente, :cfop, :tipo_pessoa, :tipo_serie, :modelo_ecf) spc on 1=1
  where p.id_produto = :id_produto
    and coalesce(spc.r_id_tributo,0) > 0
    and p.id_empresa = :id_empresa
  into r_id_empresa, r_id_produto, r_id_tributo, r_tipo_tributo, r_descricao, r_cst, r_cfop, r_prioridade, r_agregado, r_pcredsn, r_pctmedia,
       r_credito_icms, r_preco_base, r_codigo_ecf, r_aliquota_entrada, r_aliquota_saida, r_reducao_base_calculo, r_pfcp, r_orig_mercadoria,
       r_class_preco, r_cenq, r_reducao_base_import_direta, r_tipo_calculo, r_mensagem_nota_por_estado, r_aliquota_msg_cred_icms, r_aliquota_adrem;

  suspend;

end
;

CREATE OR ALTER PROCEDURE SP_RET_TRIBUTO (
    IDEMPRESA INTEGER,
    IDFILIAL INTEGER,
    IDPRODUTO VARCHAR(16),
    TIPOTRIBUTO INTEGER,
    UFORIGEM VARCHAR(2),
    UFDESTINO VARCHAR(2),
    TIPO_OPERACAO INTEGER = 0,
    TIPO_CLIENTE INTEGER = 0,
    CFOP INTEGER = 0)
RETURNS (
    R_UF_DESTINO VARCHAR(2),
    R_UF_ORIGEM VARCHAR(2),
    TRBPRODUTO INTEGER,
    TRBSUBGRUPO INTEGER,
    TRBGRUPO INTEGER,
    TRBPRIORITARIO INTEGER,
    ORIGMERCPRIORITARIO VARCHAR(1),
    CSTPRIORITARIO INTEGER,
    CODCLASERVPRIORITARIO INTEGER,
    ALIQPRIORITARIO DOUBLE PRECISION,
    TIPOTRBPRIORITARIO INTEGER)
AS
declare variable IDGRUPO integer;
declare variable IDSUBGRUPO integer;
begin

  --obtem grupo e subgrupo do produto
  select p.id_grupo_produtos, p.id_sub_grupo_produtos
  from produtos p
  join grupo_produtos gp on gp.id_empresa = p.id_empresa
                        and gp.id_grupo_produtos = p.id_grupo_produtos
  join sub_grupo_produtos sg on sg.id_empresa = p.id_empresa
                            and sg.id_sub_grupo_produtos = p.id_sub_grupo_produtos
  where p.id_empresa = :idempresa
    and p.id_produto = :idproduto
  into :idgrupo, :idsubgrupo;

  -- obtem tributo do produto
  /*
        Prioridade 1 = UF Origem e Destino definidos.
        Prioridade 2 = UF Destino definido.
        Prioridade 3 = UF Origem definido
        Prioridade 4 = Nenhuma UF definida.
        ----
        Tabela verdade
        Prioridade|Origem|Destino
        1|True |True
        2|False|True
        3|True |False
        4|False|False
  */

  --Busca do produto.
  select first 1
         coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
         coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
         trb.id_tributo,
         trb.id_tributo,
         trb.orig_mercadoria,
         trb.situacao_tributaria,
         trb.cod_class_servico,
         trb.tipo_tributo,
         te.aliquota_saida
  from produtos p
  --Prioridade 1
  left join tributos_relacionamento tr1 on tr1.id_produto = p.id_produto
                                       and tr1.id_empresa = p.id_empresa
                                       and tr1.id_filial = :idfilial
                                       and tr1.id_grupo_produtos = 0
                                       and tr1.id_sub_grupo_produtos = 0
                                       and coalesce(tr1.id_estado_orig,'') <> ''
                                       and coalesce(tr1.id_estado,'') <> ''
                                       and tr1.id_estado_orig = :uforigem
                                       and tr1.id_estado = :ufdestino
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr1.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 2
  left join tributos_relacionamento tr2 on tr2.id_produto = p.id_produto
                                       and tr2.id_empresa = p.id_empresa
                                       and tr2.id_filial = :idfilial
                                       and tr2.id_grupo_produtos = 0
                                       and tr2.id_sub_grupo_produtos = 0
                                       and coalesce(tr2.id_estado_orig,'') = ''
                                       and tr2.id_estado = :ufdestino
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr2.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 3
  left join tributos_relacionamento tr3 on tr3.id_produto = p.id_produto
                                       and tr3.id_empresa = p.id_empresa
                                       and tr3.id_filial = :idfilial
                                       and tr3.id_grupo_produtos = 0
                                       and tr3.id_sub_grupo_produtos = 0
                                       and tr3.id_estado_orig = :uforigem
                                       and coalesce(tr3.id_estado,'') = ''
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr3.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Prioridade 4
  left join tributos_relacionamento tr4 on tr4.id_produto = p.id_produto
                                       and tr4.id_empresa = p.id_empresa
                                       and tr4.id_filial = :idfilial
                                       and tr4.id_grupo_produtos = 0
                                       and tr4.id_sub_grupo_produtos = 0
                                       and coalesce(tr4.id_estado,'') = ''
                                       and coalesce(tr4.id_estado_orig,'') = ''
                                       and exists (select * from tributos t
                                                   where t.id_tributo = tr4.id_tributo
                                                     and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                     and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
  --Tributo Encontrado
  join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                   and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
  left join tributos_estados te on te.id_tributo = trb.id_tributo
                               and te.id_estado = :ufdestino
                               and te.cfop = :cfop
                               and te.id_tipo_cliente = :tipo_cliente
  where p.id_produto = :idproduto
    and p.id_empresa = :idempresa
  order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
  into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbproduto, :origmercprioritario,
       :cstprioritario, codclaservprioritario, tipotrbprioritario, :aliqprioritario;

  --Se n o econtrou busca do sub_grupo
  if (:trbprioritario is null) then
  begin

    select first 1
           coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
           coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
           trb.id_tributo,
           trb.id_tributo,
           trb.orig_mercadoria,
           trb.situacao_tributaria,
           trb.cod_class_servico,
           trb.tipo_tributo,
           te.aliquota_saida
    from sub_grupo_produtos p
    --Prioridade 1
    left join tributos_relacionamento tr1 on tr1.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr1.id_empresa = p.id_empresa
                                         and tr1.id_filial = :idfilial
                                         and tr1.id_grupo_produtos = 0
                                         and tr1.id_produto = ''
                                         and coalesce(tr1.id_estado_orig,'') <> ''
                                         and coalesce(tr1.id_estado,'') <> ''
                                         and tr1.id_estado_orig = :uforigem
                                         and tr1.id_estado = :ufdestino
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr1.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 2
    left join tributos_relacionamento tr2 on tr2.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr2.id_empresa = p.id_empresa
                                         and tr2.id_filial = :idfilial
                                         and tr2.id_grupo_produtos = 0
                                         and tr2.id_produto = ''
                                         and coalesce(tr2.id_estado_orig,'') = ''
                                         and tr2.id_estado = :ufdestino
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr2.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 3
    left join tributos_relacionamento tr3 on tr3.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr3.id_empresa = p.id_empresa
                                         and tr3.id_filial = :idfilial
                                         and tr3.id_grupo_produtos = 0
                                         and tr3.id_produto = ''
                                         and tr3.id_estado_orig = :uforigem
                                         and coalesce(tr3.id_estado,'') = ''
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr3.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Prioridade 4
    left join tributos_relacionamento tr4 on tr4.id_sub_grupo_produtos = p.id_sub_grupo_produtos
                                         and tr4.id_empresa = p.id_empresa
                                         and tr4.id_filial = :idfilial
                                         and tr4.id_grupo_produtos = 0
                                         and tr4.id_produto = ''
                                         and coalesce(tr4.id_estado,'') = ''
                                         and coalesce(tr4.id_estado_orig,'') = ''
                                         and exists (select * from tributos t
                                                     where t.id_tributo = tr4.id_tributo
                                                       and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                       and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
    --Tributo Encontrado
    join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                     and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
    left join tributos_estados te on te.id_tributo = trb.id_tributo
                                 and te.id_estado = :ufdestino
                                 and te.cfop = :cfop
                                 and te.id_tipo_cliente = :tipo_cliente
    where p.id_sub_grupo_produtos = :idsubgrupo
      and p.id_empresa = :idempresa
    order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
    into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbsubgrupo, :origmercprioritario,
         :cstprioritario, :codclaservprioritario, :tipotrbprioritario, :aliqprioritario;

    --se n o econtrou busca no grupo
    if (:trbprioritario is null) then
    begin

      select first 1
             coalesce(tr1.id_estado_orig, tr2.id_estado_orig, tr3.id_estado_orig, tr4.id_estado_orig, '') uf_origem,
             coalesce(tr1.id_estado, tr2.id_estado, tr3.id_estado, tr4.id_estado) uf_origem,
             trb.id_tributo,
             trb.id_tributo,
             trb.orig_mercadoria,
             trb.situacao_tributaria,
             trb.cod_class_servico,
             trb.tipo_tributo,
             te.aliquota_saida
      from grupo_produtos p
      --Prioridade 1
      left join tributos_relacionamento tr1 on tr1.id_grupo_produtos = p.id_grupo_produtos
                                           and tr1.id_empresa = p.id_empresa
                                           and tr1.id_filial = :idfilial
                                           and tr1.id_sub_grupo_produtos = 0
                                           and tr1.id_produto = ''
                                           and coalesce(tr1.id_estado_orig,'') <> ''
                                           and coalesce(tr1.id_estado,'') <> ''
                                           and tr1.id_estado_orig = :uforigem
                                           and tr1.id_estado = :ufdestino
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr1.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 2
      left join tributos_relacionamento tr2 on tr2.id_grupo_produtos = p.id_grupo_produtos
                                           and tr2.id_empresa = p.id_empresa
                                           and tr2.id_filial = :idfilial
                                           and tr2.id_sub_grupo_produtos = 0
                                           and tr2.id_produto = ''
                                           and coalesce(tr2.id_estado_orig,'') = ''
                                           and tr2.id_estado = :ufdestino
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr2.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 3
      left join tributos_relacionamento tr3 on tr3.id_grupo_produtos = p.id_grupo_produtos
                                           and tr3.id_empresa = p.id_empresa
                                           and tr3.id_filial = :idfilial
                                           and tr3.id_sub_grupo_produtos = 0
                                           and tr3.id_produto = ''
                                           and tr3.id_estado_orig = :uforigem
                                           and coalesce(tr3.id_estado,'') = ''
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr3.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Prioridade 4
      left join tributos_relacionamento tr4 on tr4.id_grupo_produtos = p.id_grupo_produtos
                                           and tr4.id_empresa = p.id_empresa
                                           and tr4.id_filial = :idfilial
                                           and tr4.id_sub_grupo_produtos = 0
                                           and tr4.id_produto = ''
                                           and coalesce(tr4.id_estado,'') = ''
                                           and coalesce(tr4.id_estado_orig,'') = ''
                                           and exists (select * from tributos t
                                                       where t.id_tributo = tr4.id_tributo
                                                         and t.tipo_operacao in(coalesce(:tipo_operacao,0),0)
                                                         and (((:tipotributo > 0) and (t.tipo_tributo = :tipotributo)) or (:tipotributo = 0)))
      --Tributo Encontrado
      join tributos trb on trb.id_tributo = coalesce(tr1.id_tributo, coalesce(tr2.id_tributo, coalesce(tr3.id_tributo, tr4.id_tributo)))
                       and (((:tipotributo > 0) and (trb.tipo_tributo = :tipotributo)) or (:tipotributo = 0))
      left join tributos_estados te on te.id_tributo = trb.id_tributo
                                   and te.id_estado = :ufdestino
                                   and te.cfop = :cfop
                                   and te.id_tipo_cliente = :tipo_cliente
      where p.id_grupo_produtos = :idgrupo
        and p.id_empresa = :idempresa
      order by trb.tipo_tributo, coalesce(:tipo_operacao,0)
      into :r_uf_origem, :r_uf_destino, :trbprioritario, :trbgrupo, :origmercprioritario,
           :cstprioritario, :codclaservprioritario, :tipotrbprioritario, :aliqprioritario;

    end

  end

  -- retorna valores nulos para os nao encontrados para uso com coalesce()
  trbproduto  = nullif(:trbproduto, 0);
  trbsubgrupo = nullif(:trbsubgrupo, 0);
  trbgrupo    = nullif(:trbgrupo, 0);

  suspend;

end
;

alter table lancamentos_banco
  alter historico type varchar(1000)
;

create or alter procedure SP_GLANCAMENTOS_BANCO (
    ID_LANCAMENTO_BANCO integer,
    ID_CONTA_CREDITO integer,
    ID_CONTA_DEBITO integer,
    ID_GRUPO_LANCAMENTOS integer,
    ID_SUBGRUPO_LANCAMENTOS integer,
    VALOR double precision,
    DATA_LANCAMENTO date,
    DATA_PREVISAO date,
    DATA_CONSOLIDACAO date,
    DOCUMENTO varchar(15),
    HISTORICO varchar(1000),
    BAIXA integer,
    SITUACAO integer,
    DATA_ATUAL date,
    ID_USUARIO integer,
    ID_EMPRESA integer,
    ID_FILIAL integer,
    ID_CENTRO_CUSTO integer,
    ORIGEM integer,
    MOTIVO_ESTORNO varchar(1000),
    TPLANCAMENTO varchar(1),
    ID_CAIXA integer,
    ID_LANCAMENTO_CAIXA integer,
    NOME_ARQUIVO_CONSOLIDACAO varchar(1000),
    ID_ARQUIVO_CONSOLIDACAO varchar(300))
returns (
    NEWCOD integer)
as
begin

  if (:id_lancamento_banco = 0) then
  begin

    newcod = gen_id(gen_lancamentos_banco, 1);

    insert into lancamentos_banco(id_lancamento_banco,
                                  id_conta_credito,
                                  id_conta_debito,
                                  id_grupo_lancamentos,
                                  id_subgrupo_lancamentos,
                                  valor,
                                  data_lancamento,
                                  data_previsao,
                                  data_consolidacao,
                                  documento,
                                  historico,
                                  baixa,
                                  situacao,
                                  data_atual,
                                  id_usuario,
                                  id_centro_custo,
                                  id_empresa,
                                  id_filial,
                                  origem,
                                  motivo_estorno,
                                  tplancamento,
                                  id_caixa,
                                  id_lancamento_caixa,
                                  nome_arquivo_consolidacao,
                                  id_arquivo_consolidacao)
      values(:newcod,
             :id_conta_credito,
             :id_conta_debito,
             :id_grupo_lancamentos,
             :id_subgrupo_lancamentos,
             :valor,
             :data_lancamento,
             :data_previsao,
             :data_consolidacao,
             :documento,
             :historico,
             :baixa,
             :situacao,
             :data_atual,
             :id_usuario,
             :id_centro_custo,
             :id_empresa,
             :id_filial,
             :origem,
             :motivo_estorno,
             :tplancamento,
             :id_caixa,
             :id_lancamento_caixa,
             :nome_arquivo_consolidacao,
             :id_arquivo_consolidacao);

  end
  else
  begin

    newcod = :id_lancamento_banco;

    update lancamentos_banco
    set historico = :historico,
        baixa = :baixa,
        situacao = :situacao,
        data_atual = :data_atual,
        id_usuario = :id_usuario,
        id_empresa = :id_empresa,
        id_filial = :id_filial,
        data_lancamento = :data_lancamento,
        data_previsao = :data_previsao,
        data_consolidacao = :data_consolidacao,
        documento = :documento,
        id_centro_custo = :id_centro_custo,
        motivo_estorno = :motivo_estorno,
        tplancamento = :tplancamento
    where id_lancamento_banco = :id_lancamento_banco
      and id_empresa = :id_empresa
      and id_filial = :id_filial;

  end

end
;

CREATE OR ALTER TRIGGER CONTAS_PAG_REC_DOCUMENTOS_BI0 FOR CONTAS_PAG_REC_DOCUMENTOS
ACTIVE BEFORE INSERT OR UPDATE POSITION 0
AS
declare variable icount integer;
declare variable v_id_inst_fin integer;
declare variable v_id_conta_banco integer;
begin

select id_instituicao_financeira, id_conta_banco
    from contas_pag_rec
    where id_empresa = new.id_empresa
      and id_filial = new.id_filial
      and tipo = new.tipo
      and id_contas_pag_rec = new.id_contas_pag_rec
    into :v_id_inst_fin, :v_id_conta_banco;

  select count(*)
    from contas_pag_rec_documentos d
    left join contas_pag_rec r on r.id_empresa = d.id_empresa
      and r.id_filial = d.id_filial
      and r.tipo = d.tipo
      and r.id_contas_pag_rec = d.id_contas_pag_rec
    where d.id_empresa = new.id_empresa
      and d.id_filial = new.id_filial
      and d.id_contas_pag_rec <> new.id_contas_pag_rec
      and d.tipo = new.tipo
      and trim(d.id_documento_vinculado) = trim(new.id_documento_vinculado)
      and new.tipo in (2,3)
      and r.id_instituicao_financeira = :v_id_inst_fin
      and r.id_conta_banco = :v_id_conta_banco
    into :icount;

   if (:icount > 0) then
    exception erwin_erro_padrao ascii_char(13) || ascii_char(10) || ' *** JA EXISTE OUTRO TITULO COM ESSE MESMO NUMERO DE DOCUMENTO VINCULADO ***' || ascii_char(13) || ascii_char(10);

end
;






