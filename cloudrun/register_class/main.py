from cloudevents.http import CloudEvent
import functions_framework

@functions_framework.cloud_event
def register_class(event: CloudEvent):
    # Firestore triggers arrive via Eventarc.
    # We'll add parsing + Firestore transaction next.
    print("event type:", event["type"])
    print("event subject:", event.get("subject"))
