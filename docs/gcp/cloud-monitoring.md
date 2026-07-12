# Configuração do Cloud Monitoring

## Canal de notificação

1. Abra **Monitoring**.
2. Entre em **Alerting**.
3. Clique em **Edit notification channels**.
4. Em **Email**, clique em **Add new**.
5. Informe um nome e um e-mail válido.
6. Confirme o e-mail recebido.
7. Edite as três políticas com prefixo `FIAP -` e associe esse canal.

## Alerta de erro do Dataflow baseado em logs

1. Abra **Logging → Logs Explorer**.
2. Use:

```text
resource.type="dataflow_step"
severity>=ERROR
```

3. Clique em **Create alert**.
4. Nome: `FIAP - Erro no Dataflow`.
5. Configure qualquer correspondência em cinco minutos.
6. Associe o canal de e-mail.
7. Salve.

## Dashboard

Use os dashboards nativos de Pub/Sub e Dataflow e crie um dashboard:

`FIAP - Pipeline Alfabetização`

Inclua:

1. Pub/Sub — mensagens não entregues;
2. Pub/Sub — idade da mensagem não confirmada mais antiga;
3. Dataflow — system lag;
4. Dataflow — elementos processados.

## Evidência textual

```bash
gcloud monitoring policies list   --project="$PROJECT_ID"   --filter="displayName:FIAP"   --format="table(displayName,enabled,name)"
```

Não é necessário salvar screenshots.
