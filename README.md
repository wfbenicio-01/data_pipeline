# 🧠 RAG Serverless Pipeline com Terraform + GitHub Actions

Este projeto provisiona uma arquitetura **serverless** completa na AWS para ingestão de arquivos de texto, áudio e vídeo, com transcrição, geração de embeddings e indexação em OpenSearch, utilizando:

- AWS Lambda (com Whisper, MoviePy, Sentence Transformers)
- AWS S3 (buckets bronze, gold e deploy)
- AWS Step Functions
- SQS + EC2 fallback para arquivos grandes
- OpenSearch como banco vetorial
- CI/CD com GitHub Actions
- Infraestrutura como código com Terraform

---

## ✅ Pré-requisitos

### 1. Conta AWS com permissões:

Seu usuário IAM precisa de permissões para:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:*", "lambda:*", "iam:*", "ec2:*",
    "sqs:*", "logs:*", "states:*"
  ],
  "Resource": "*"
}
```

---

### 2. Configurar **Secrets** no GitHub

Acesse: `Settings > Secrets and variables > Actions` e adicione:

| Nome do Secret             | Descrição                          |
|---------------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`       | Access key da sua conta AWS        |
| `AWS_SECRET_ACCESS_KEY`   | Secret key da sua conta AWS        |
| `NAME_PREFIX`             | Prefixo para os recursos (ex: `myproject-dev`) |

---

## 🚀 Deploy Automático (CI/CD)

Ao fazer push na branch `main`, o GitHub Actions irá:

1. Rodar `terraform init`, `fmt`, `validate`, `plan`
2. Fazer `apply` automático da infraestrutura
3. Fazer upload automático dos zips para o S3 bucket
4. Provisionar as funções Lambda com código via S3

---

## 📁 Estrutura dos diretórios

```
.
├── deploy/                  # Pacotes .zip para cada Lambda
├── functions/               # Código-fonte das funções Lambda
│   ├── audio_processor/
│   ├── video_processor/
│   ├── text_processor/
│   └── detect_file/
├── main.tf                  # Terraform principal
└── .github/workflows/
    └── terraform.yml        # CI/CD GitHub Actions
```

---

## 📦 Como usar

1. Suba este repositório no seu GitHub
2. Configure os 3 secrets obrigatórios
3. Faça um commit na branch `main`
4. Aguarde o deploy automático

---

## 🧠 O que acontece

- Arquivo enviado para S3 bucket bronze
- Lambda detecta o tipo e dispara a Step Function
- Step Function processa conforme tipo (texto, áudio, vídeo)
- Se for muito grande, envia para fallback SQS
- EC2 consome SQS e processa com Whisper, MoviePy etc.
- Resultado é salvo no bucket gold e indexado no OpenSearch

---

## ✨ Licença

Este projeto é open source e pode ser usado para fins educacionais, POCs e produção com ajustes.
