##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  sns_topics_names = merge([
    for key, synthetic in local.synthetics : {
      for notification in try(synthetic.canary.alarms.notifications, []) : "${key}-${notification.sns_topic_name}" => {
        key  = key
        name = notification.sns_topic_name
      }
      if try(synthetic.canary.alarms.enabled, true) && var.create_alarms && try(notification.sns_topic_name, "") != ""
    }
  ]...)
  sns_topics_arns = merge([
    for key, synthetic in local.synthetics : {
      for notification in try(synthetic.canary.alarms.notifications, []) : "${key}-${notification.sns_topic_arn}" => {
        key = key
        arn = notification.sns_topic_arn
      }
      if try(synthetic.canary.alarms.enabled, true) && var.create_alarms && try(notification.sns_topic_arn, "") != ""
    }
  ]...)
  default_statistic = {
    "SuccessPercent" = "Average"
    "Failure"        = "Sum"
    "Duration"       = "Average"
  }
}

data "aws_sns_topic" "default_topic" {
  count = var.default_sns_topic_name != "" ? 1 : 0
  name  = var.default_sns_topic_name
}

data "aws_sns_topic" "topics_by_name" {
  for_each = local.sns_topics_names
  name     = each.value.name
}

resource "aws_cloudwatch_metric_alarm" "canary_failed" {
  for_each = {
    for key, synthetic in local.synthetics : key => synthetic
    if try(synthetic.canary.alarms.enabled, true) && var.create_alarms
  }
  alarm_name          = "[P${try(each.value.canary.alarms.priority, 4)}] Synthetic Failed - ${each.value.canary_final_name}"
  alarm_description   = try(format("This alarm is triggered when the canary fails. %s", each.value.canary.description), var.alarms_defaults.description)
  comparison_operator = try(each.value.canary.alarms.condition, var.alarms_defaults.condition)
  evaluation_periods  = try(each.value.canary.alarms.evaluation_periods, var.alarms_defaults.evaluation_periods)
  metric_name         = try(each.value.canary.alarms.metric, var.alarms_defaults.metric)
  namespace           = "CloudWatchSynthetics"
  period              = try(each.value.canary.alarms.period, var.alarms_defaults.period)
  statistic           = try(each.value.canary.alarms.statistic, local.default_statistic[try(each.value.canary.alarms.metric, var.alarms_defaults.metric)])
  threshold           = try(each.value.canary.alarms.threshold, var.alarms_defaults.threshold)
  dimensions = {
    CanaryName = each.value.canary_final_name
  }
  alarm_actions = concat(
    [
      for key, topic in local.sns_topics_arns : topic.arn
    ],
    [
      for key, topic in local.sns_topics_names : data.aws_sns_topic.topics_by_name[key].arn
    ],
    var.default_sns_topic_name != "" ? [data.aws_sns_topic.default_topic[0].arn] : []
  )
  ok_actions = concat(
    [
      for key, topic in local.sns_topics_arns : topic.arn
    ],
    [
      for key, topic in local.sns_topics_names : data.aws_sns_topic.topics_by_name[key].arn
    ],
    var.default_sns_topic_name != "" ? [data.aws_sns_topic.default_topic[0].arn] : []
  )
  insufficient_data_actions = []
  tags = merge(
    local.all_tags,
    try(each.value.group.tags, {}),
    try(each.value.canary.tags, {}),
    {
      synthetic_group_key  = each.value.group.name
      synthetic_canary_key = each.value.canary.name
      alarm_priority       = try(each.value.canary.alarms.priority, 4)
    }
  )
  depends_on = [
    aws_synthetics_canary.this
  ]
}