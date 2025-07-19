# ECS Blue/Green Deployment Demo with Terraform

AWS ECS のネイティブ Blue/Green デプロイメント機能（2025年7月17日リリース）を Terraform で実装するデモプロジェクトです。

## アーキテクチャ

```
Internet
    ↓
ALB (Production Listener: 80, Test Listener: 8080)
    ↓
Target Groups (Blue/Green)
    ↓
ECS Fargate Tasks
```

## ディレクトリ構造

```
.
├── README.md
├── app/                           # サンプルWebアプリケーション
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   └── main.go                    # Go + Gin Webサーバー
└── terraform/                    # Terraformコード
    ├── alb.tf                     # ALB関連リソース
    ├── ecr.tf                     # ECRリポジトリ
    ├── ecs.tf                     # ECSクラスター・サービス
    ├── iam.tf                     # IAMロール・ポリシー
    ├── lambda.tf                  # Lambda関数
    ├── lambda_functions/
    │   └── health_check_test.py   # ライフサイクルフック用Lambda
    ├── outputs.tf                 # 出力値
    ├── provider.tf                # Terraformプロバイダ設定
    ├── task-definition.json       # ECSタスク定義テンプレート
    ├── variables.tf               # 変数定義
    ├── vpc.tf                     # VPC設定
    └── vpc_endpoints.tf           # VPCエンドポイント
```

## 主要ファイルの説明

### app/main.go
- Go + Gin によるシンプルなWebサーバー
- `/health`: ヘルスチェック用エンドポイント
- `/`: メイン機能（Lambda関数のテスト対象）

### terraform/ecs.tf
ECS Blue/Green デプロイメントの核となる設定:
```hcl
deployment_configuration {
  strategy             = "BLUE_GREEN"
  bake_time_in_minutes = 5
  
  lifecycle_hook {
    hook_target_arn  = aws_lambda_function.health_check_test.arn
    role_arn         = aws_iam_role.ecs_blue_green.arn
    lifecycle_stages = ["POST_TEST_TRAFFIC_SHIFT"]
  }
}

load_balancer {
  advanced_configuration {
    alternate_target_group_arn = aws_lb_target_group.green.arn
    production_listener_rule   = aws_lb_listener_rule.production.arn
    test_listener_rule         = aws_lb_listener_rule.test.arn
    role_arn                   = aws_iam_role.ecs_blue_green.arn
  }
}
```

### terraform/lambda_functions/health_check_test.py
ライフサイクルフック用Lambda関数:
- テストリスナーの `/` エンドポイントをチェック
- `hookStatus: SUCCEEDED/FAILED` でデプロイ継続/ロールバックを制御

## 前提条件

- AWS CLI設定済み
- Terraform >= 1.0
- Docker
- Go >= 1.19

## セットアップ手順

### 1. Terraformでインフラをデプロイ

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. アプリケーションをビルド・プッシュ

```bash
# ECRリポジトリURLを取得
ECR_REPOSITORY_URL=$(cd terraform && terraform output -raw ecr_repository_url)

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin $ECR_REPOSITORY_URL

# アプリケーションをビルド・プッシュ
cd app
docker build -t blue-green-demo .
docker tag blue-green-demo:latest $ECR_REPOSITORY_URL:latest
docker push $ECR_REPOSITORY_URL:latest
```

### 3. ECSタスク定義を登録

```bash
cd ..
aws ecs register-task-definition \
  --family blue-green-demo \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 256 \
  --memory 512 \
  --execution-role-arn "$(aws iam get-role --role-name blue-green-demo-ecs-task-execution-role --query 'Role.Arn' --output text)" \
  --container-definitions "[{\"name\":\"blue-green-demo\",\"image\":\"$ECR_REPOSITORY_URL:latest\",\"cpu\":0,\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}]}]"
```

## 動作確認

### Blue/Green デプロイメントの実行

```bash
# 新しいデプロイメントを開始
aws ecs update-service \
  --cluster blue-green-demo \
  --service blue-green-demo \
  --force-new-deployment
```

### デプロイメント状況の監視

```bash
# ECSサービスイベントの確認
aws ecs describe-services \
  --cluster blue-green-demo \
  --services blue-green-demo \
  --query 'services[0].events[:5]'

# デプロイメント詳細の確認
aws ecs describe-services \
  --cluster blue-green-demo \
  --services blue-green-demo \
  --query 'services[0].deployments'
```

### ターゲットグループの健全性確認

```bash
# Blue環境の確認
aws elbv2 describe-target-health \
  --target-group-arn $(cd terraform && terraform output -raw blue_target_group_arn)

# Green環境の確認
aws elbv2 describe-target-health \
  --target-group-arn $(cd terraform && terraform output -raw green_target_group_arn)
```

### ALBエンドポイントへのアクセス

```bash
# ALB URLを取得
ALB_URL=$(cd terraform && terraform output -raw alb_url)

# Production環境へアクセス（ポート80）
curl http://$ALB_URL/

# Test環境へアクセス（ポート8080）
curl http://$ALB_URL:8080/

# ヘルスチェックエンドポイント
curl http://$ALB_URL/health
curl http://$ALB_URL:8080/health
```

### Lambda関数のログ確認

```bash
# Lambda関数のログストリーム確認
aws logs describe-log-streams \
  --log-group-name /aws/lambda/blue-green-demo-health-check-test \
  --order-by LastEventTime \
  --descending

# 最新のログイベント確認
aws logs get-log-events \
  --log-group-name /aws/lambda/blue-green-demo-health-check-test \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /aws/lambda/blue-green-demo-health-check-test \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)
```

## 失敗テストの実行

デプロイメントが失敗した場合のロールバック動作を確認:

### 1. アプリケーションにバグを仕込む

```go
// app/main.go のルートエンドポイントを変更
r.GET("/", func(c *gin.Context) {
    response := Response{
        Message: "Hello from Blue/Green Demo with Gin!",
        Version: version,
    }
    c.JSON(http.StatusInternalServerError, response) // 500エラーを返す
})
```

### 2. 新しいイメージをプッシュ

```bash
cd app
docker build -t blue-green-demo .
docker tag blue-green-demo:latest $ECR_REPOSITORY_URL:latest
docker push $ECR_REPOSITORY_URL:latest
```

### 3. 新しいタスク定義を登録

```bash
aws ecs register-task-definition \
  --family blue-green-demo \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 256 \
  --memory 512 \
  --execution-role-arn "$(aws iam get-role --role-name blue-green-demo-ecs-task-execution-role --query 'Role.Arn' --output text)" \
  --container-definitions "[{\"name\":\"blue-green-demo\",\"image\":\"$ECR_REPOSITORY_URL:latest\",\"cpu\":0,\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}]}]"
```

### 4. デプロイメントを実行

```bash
# 新しいタスク定義でデプロイメント開始
aws ecs update-service \
  --cluster blue-green-demo \
  --service blue-green-demo
```

Lambda関数が500エラーを検知してロールバックが実行されることを確認できます。

## トラブルシューティング

### よくある問題

1. **デプロイメントが失敗する**
   - ヘルスチェックエンドポイント（`/health`）が200を返しているか確認
   - Lambda関数のCloudWatchログを確認
   - ECSタスクのログを確認

2. **タスクが起動しない**
   - ECRリポジトリにイメージがプッシュされているか確認
   - IAMロールの権限を確認
   - VPCエンドポイントの設定を確認

### 有用なコマンド

```bash
# ECSタスクのログ確認
aws ecs describe-task-definition \
  --task-definition blue-green-demo \
  --query 'taskDefinition.containerDefinitions[0].logConfiguration'

# タスクの詳細確認
aws ecs list-tasks \
  --cluster blue-green-demo \
  --service-name blue-green-demo

# 特定のタスクの詳細
aws ecs describe-tasks \
  --cluster blue-green-demo \
  --tasks <TASK_ARN>
```

## クリーンアップ

```bash
cd terraform
terraform destroy
```

## 参考資料

- [AWS Blog: Amazon ECS built-in blue/green deployments](https://aws.amazon.com/jp/about-aws/whats-new/2025/07/amazon-ecs-built-in-blue-green-deployments/)
- [AWS Docs: Lifecycle hooks for Amazon ECS service deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-lifecycle-hooks.html)
- [AWS Docs: How Amazon ECS blue/green deployment works](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/blue-green-deployment-how-it-works.html)
