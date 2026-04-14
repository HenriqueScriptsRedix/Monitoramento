# Regra de negócio — Campo de Storage no monitoramento Veeam

## Objetivo

Padronizar a identificação do destino de armazenamento dos jobs monitorados, criando uma classificação simples e consistente para exibição e coleta.

A proposta é separar o comportamento em dois níveis:

- **Campo principal**: identifica a categoria do storage
- **Campo de detalhe**: descreve o destino de forma legível

---

## Campos propostos

### Campo principal

    StorageType

Valores possíveis:

- `Tape`
- `Disk`
- `SOBR`

### Campo de detalhe

Sugestão de nome:

    StorageDetail

Esse campo será usado para exibir o nome, tipo e destino do storage de forma amigável.

---

## Regra principal de classificação

A definição do `StorageType` seguirá esta prioridade:

1. Se o job for de fita, o tipo será **Tape**
2. Se o destino for um **Scale-Out Backup Repository**, o tipo será **SOBR**
3. Nos demais casos, o tipo será **Disk**

---

## Possibilidades por tipo

### 1. Tape

#### StorageType

    Tape

#### Formato do detalhe

    Tape (Media Pool: <PoolName>)

#### Exemplo

    Tape (Media Pool: Full-Weekly)

#### Regra de negócio

Quando o job utilizar fita como destino, o monitoramento deve:

- classificar o `StorageType` como `Tape`
- exibir no detalhe o nome do **Media Pool** associado ao job

---

### 2. Disk

#### StorageType

    Disk

#### Formato-base do detalhe

    Disk [ <RepositoryName> ( <RepositoryKind>: <PathOrTarget> ) ]

#### Regra de negócio

Quando o job utilizar um repositório único e não for SOBR nem Tape, o monitoramento deve:

- classificar o `StorageType` como `Disk`
- exibir no detalhe:
  - o nome do repositório
  - o tipo do repositório
  - o caminho, bucket ou destino correspondente

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

### 2.4 Object Storage como repositório único

Mesmo sendo tecnicamente object storage, dentro desta taxonomia simplificada ele será classificado como **Disk**, pois não é Tape nem SOBR.

#### Exemplos

    Disk [ Repository_08 ( Object Storage: Amazon S3 / bucket-backup-prod ) ]
    Disk [ Repository_09 ( Object Storage: Azure Blob / container-veeam ) ]
    Disk [ Repository_10 ( Object Storage: Wasabi / bucket01 ) ]

#### Regra

Quando o destino for um object storage repository isolado, exibir:

- nome do repositório
- identificador `Object Storage`
- provedor e bucket/container correspondente

---

### 3. SOBR

#### StorageType

    SOBR

#### Formato-base do detalhe

    SOBR [ <SobrName> | Performance: (...) | Capacity: (...) | Archive: (...) ]

#### Regra de negócio

Quando o destino do job for um **Scale-Out Backup Repository**, o monitoramento deve:

- classificar o `StorageType` como `SOBR`
- exibir no detalhe:
  - nome do SOBR
  - tier de performance, se existir
  - tier de capacity, se existir
  - tier de archive, se existir

A exibição deve listar os componentes disponíveis de acordo com a configuração real do SOBR.

---

## Subregras para SOBR

### 3.1 SOBR com apenas Performance Tier

#### Formato

    SOBR [ SOBR_01 | Performance: (REPO_01: C:\Backup) (REPO_02: D:\Backup) ]

#### Regra

Quando o SOBR possuir apenas performance tier, exibir somente os extents dessa camada.

---

### 3.2 SOBR com Performance + Capacity

#### Formato

    SOBR [ SOBR_02 | Performance: (REPO_01: /backup) | Capacity: (Amazon S3: bucket-veeam-capacity) ]

#### Regra

Quando o SOBR possuir performance tier e capacity tier, exibir ambos no detalhe.

---

### 3.3 SOBR com Performance + Capacity + Archive

#### Formato

    SOBR [ SOBR_03 | Performance: (REPO_01: /backup) | Capacity: (Amazon S3: bucket-veeam-capacity) | Archive: (Azure Archive: archive-container) ]

#### Regra

Quando o SOBR possuir os três níveis, exibir os três no detalhe.

---

## Resumo final da padronização

### Campo principal

    StorageType = Tape | Disk | SOBR

### Campo de detalhe

    StorageDetail = descrição legível do destino

---

## Estrutura final esperada

### Tape

    StorageType   = Tape
    StorageDetail = Tape (Media Pool: Full-Weekly)

### Disk — Windows

    StorageType   = Disk
    StorageDetail = Disk [ Repository_01 ( Windows: D:\Backups ) ]

### Disk — Linux

    StorageType   = Disk
    StorageDetail = Disk [ Repository_02 ( Linux: /mnt/backup ) ]

### Disk — Hardened

    StorageType   = Disk
    StorageDetail = Disk [ Repository_03 ( Hardened Linux: /backup ) ]

### Disk — Object Storage

    StorageType   = Disk
    StorageDetail = Disk [ Repository_08 ( Object Storage: Amazon S3 / bucket-backup-prod ) ]

### SOBR — apenas Performance

    StorageType   = SOBR
    StorageDetail = SOBR [ SOBR_01 | Performance: (REPO_01: C:\Backup) (REPO_02: D:\Backup) ]

### SOBR — Performance + Capacity

    StorageType   = SOBR
    StorageDetail = SOBR [ SOBR_02 | Performance: (REPO_01: /backup) | Capacity: (Amazon S3: bucket-veeam-capacity) ]

---

## Decisão funcional consolidada

A regra de negócio ficará assim:

- **Tape**: sempre exibir o Media Pool
- **Disk**: sempre exibir nome do repositório, tipo do repositório e caminho/destino
- **SOBR**: sempre exibir o nome do SOBR e os tiers existentes com seus respectivos destinos

Essa será a base para implementação futura no script.