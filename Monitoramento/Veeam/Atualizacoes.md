# Regra de negócio — Campo de Storage no monitoramento Veeam

## Objetivo

Padronizar a identificação do destino de armazenamento dos jobs monitorados, criando uma classificação simples e consistente para exibição e coleta.

A proposta final é utilizar **um único campo** de saída:

- **StorageDetail**: descrição legível do destino do backup

---

## Campo adotado

### Campo de detalhe

    StorageDetail

Esse campo será usado para exibir o nome, tipo e destino do storage de forma amigável.

---

## Regra principal de classificação

A definição do `StorageDetail` seguirá esta prioridade lógica:

1. Se o job for de fita, exibir como **Tape**
2. Se o destino for um **Scale-Out Backup Repository**, exibir como **SOBR**
3. Se o destino for object storage AWS, exibir como **S3**
4. Nos demais casos, exibir como **Disk**

---

## Possibilidades por tipo

### 1. Tape

#### Formato do detalhe

    Tape (Media Pool: <PoolName>)

#### Exemplo

    Tape (Media Pool: Full-Weekly)

#### Regra de negócio

Quando o job utilizar fita como destino, o monitoramento deve:

- exibir no detalhe o nome do **Media Pool** associado ao job

---

### 2. Disk

#### Formato-base do detalhe

    Disk [ <RepositoryName> ( <RepositoryKind>: <PathOrTarget> ) ]

#### Regra de negócio

Quando o job utilizar um repositório único e não for SOBR, Tape ou S3, o monitoramento deve exibir:

- o nome do repositório
- o tipo do repositório
- o caminho ou destino correspondente

---

## Subregras para Disk

### 2.1 Windows repository

#### Formato

    Disk [ Repository_01 ( Windows: D:\Backups ) ]

#### Regra

Quando o repositório for Windows, exibir:

- nome do repositório
- identificador `Windows`
- path local configurado

---

### 2.2 Linux repository

#### Formato

    Disk [ Repository_02 ( Linux: /mnt/backup ) ]

#### Regra

Quando o repositório for Linux padrão, exibir:

- nome do repositório
- identificador `Linux`
- path configurado

---

### 2.3 Hardened repository

#### Formato

    Disk [ Repository_03 ( Hardened Linux: /backup ) ]

#### Regra

Quando o repositório for Hardened Repository, exibir explicitamente que ele é **Hardened Linux**, e não apenas o path.

O objetivo é deixar claro no monitoramento que o destino possui característica hardened.

---

### 3. S3

#### Formato-base do detalhe

    S3 [ <RepositoryName> ( Object Storage: Amazon S3 ) ]

#### Exemplos

    S3 [ S3_AWS ( Object Storage: Amazon S3 ) ]
    S3 [ AWS_S3 ( Object Storage: Amazon S3 ) ]

#### Regra de negócio

Quando o destino for object storage AWS, o monitoramento deve:

- exibir o prefixo `S3`
- exibir o nome do repositório
- exibir `Object Storage: Amazon S3`

Não é necessário detalhar bucket ou container.

---

### 4. SOBR

#### Formato-base do detalhe

    SOBR [ <SobrName> | Performance: (...) | Capacity: (...) ]

#### Regra de negócio

Quando o destino do job for um **Scale-Out Backup Repository**, o monitoramento deve exibir:

- nome do SOBR
- tier de performance, se existir
- tier de capacity, se existir

A exibição deve listar os componentes disponíveis de acordo com a configuração real do SOBR.

> Observação:
> O tier **Archive** não será exibido na implementação atual.

---

## Subregras para SOBR

### 4.1 SOBR com apenas Performance Tier

#### Formato

    SOBR [ SOBR_01 | Performance: (REPO_01: C:\Backup) (REPO_02: D:\Backup) ]

#### Regra

Quando o SOBR possuir apenas performance tier, exibir somente os extents dessa camada.

---

### 4.2 SOBR com Performance + Capacity

#### Formato

    SOBR [ SOBR_02 | Performance: (REPO_01: /backup) | Capacity: (AWS_S3) ]

#### Regra

Quando o SOBR possuir performance tier e capacity tier, exibir ambos no detalhe.

---

### 4.3 SOBR sem detalhamento disponível

#### Formato

    SOBR [ SOBR_02 ]

#### Regra

Quando o script conseguir identificar que o destino é um SOBR, mas não conseguir expandir os tiers disponíveis, o monitoramento deve exibir ao menos o nome do SOBR.

Esse comportamento é aceito como fallback para preservar a identificação correta do destino.

---

## Resumo final da padronização

### Campo adotado

    StorageDetail = descrição legível do destino

---

## Estrutura final esperada

### Tape

    StorageDetail = Tape (Media Pool: Full-Weekly)

### Disk — Windows

    StorageDetail = Disk [ Repository_01 ( Windows: D:\Backups ) ]

### Disk — Linux

    StorageDetail = Disk [ Repository_02 ( Linux: /mnt/backup ) ]

### Disk — Hardened

    StorageDetail = Disk [ Repository_03 ( Hardened Linux: /backup ) ]

### S3

    StorageDetail = S3 [ S3_AWS ( Object Storage: Amazon S3 ) ]

### SOBR — apenas Performance

    StorageDetail = SOBR [ SOBR_01 | Performance: (REPO_01: C:\Backup) (REPO_02: D:\Backup) ]

### SOBR — Performance + Capacity

    StorageDetail = SOBR [ SOBR_02 | Performance: (Repo_03: E:\Repo_03) | Capacity: (AWS_S3) ]

### SOBR — fallback

    StorageDetail = SOBR [ SOBR_02 ]

---

## Decisão funcional consolidada

A regra de negócio ficará assim:

- **Tape**: sempre exibir o Media Pool
- **Disk**: sempre exibir nome do repositório, tipo do repositório e caminho/destino
- **S3**: sempre exibir o nome do repositório e `Object Storage: Amazon S3`
- **SOBR**: sempre exibir o nome do SOBR e, quando possível, os tiers de Performance e Capacity

Essa será a base para implementação e manutenção dos scripts de monitoramento.