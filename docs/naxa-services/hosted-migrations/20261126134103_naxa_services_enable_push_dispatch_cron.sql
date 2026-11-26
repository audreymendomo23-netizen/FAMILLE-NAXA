select cron.schedule('naxa-services-push-dispatch','*/5 * * * *','select ns_private.enqueue_notification_dispatch(false);');
