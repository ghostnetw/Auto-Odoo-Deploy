{
    "name": "QuickBooks Style Bank Reconciliation",
    "summary": "Bank reconciliation interface inspired by QuickBooks with manual reconciliation features",
    "description": """
        Manual Bank Reconciliation module with QuickBooks-style interface
        Features:
        - Multi-company support
        - Manual checkmark for matching entries
        - Search and filter functionality
        - Save sessions for later
        - Opening and closing balance tracking
        - Difference calculation
    """,
    "version": "1.0",
    "category": "Accounting",
    "author": "edgar el hacker",
    "website": "",
    "license": "LGPL-3",
    "depends": [
        "base"
    ],
    "data": [
        "security/ir.model.access.csv",
        "views/reconcile_view.xml",
        "views/menu_items.xml",
        "views/bank_views.xml"
    ],
    "assets": {
        "web.assets_backend": [
            "/qb_style_bank_reconcile/static/src/css/reconcile.css",
            "/qb_style_bank_reconcile/static/src/js/reconcile.js"
        ]
    },
    "images": [],
    "demo": [],
    "installable": True,
    "application": True,
    "auto_install": False,
    "sequence": 1
}
