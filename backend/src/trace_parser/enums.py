import enum


class NodeStatus(enum.Enum):
    triggered = "triggered"
    not_triggered = "not_triggered"


class NodeLabel(enum.Enum):
    USER_QUERY_AGENT = "Command Routing Agent"
    PLANNING_AGENT = "Planning Agent"
    PRODUCT_PERSONALIZATION_AGENT = "Product Personalization Agent"
    REVIEW_AGENT = "Review Agent"
    EVALUATION_AGENT = "Evaluation Agent"
    INVENTORY_AGENT = "Inventory Agent"
    PRESENTATION_AGENT = "Presentation Agent"
    WORKFLOW_COMPLETE = "Workflow Complete"
    SEARCH_PRODUCTS = "Tool: Search Products"
    QUERY_ABOUT_PRODUCT = "Tool: Query About Product"
    QUERY_REVIEWS_WITH_SENTIMENTS = "Tool: Query Reviews With Sentiments"
