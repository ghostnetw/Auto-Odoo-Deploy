from odoo import models, fields, api, _
from odoo.exceptions import UserError


class QBReconcileWizard(models.Model):
    _name = 'qb.reconcile.wizard'
    _description = 'QuickBooks Style Reconciliation Wizard'

    name = fields.Char(string='Name', compute='_compute_name', store=True)
    company_id = fields.Many2one('res.company', string='Company', required=True, default=lambda self: self.env.company)
    bank_account_id = fields.Many2one('qb.bank.account', string='Bank Account', required=True, domain="[('company_id', '=', company_id)]")
    currency_id = fields.Many2one(related='bank_account_id.currency_id')
    date_from = fields.Date(string='Start Date', required=True)
    date_to = fields.Date(string='End Date', required=True)
    opening_balance = fields.Monetary(string='Opening Balance', required=True, currency_field='currency_id')
    closing_balance = fields.Monetary(string='Closing Balance', required=True, currency_field='currency_id')
    statement_line_ids = fields.Many2many('qb.bank.statement', string="Bank Statement Lines")
    journal_item_ids = fields.Many2many('qb.journal.entry', string="Journal Entries")
    reconciled_line_ids = fields.Many2many('qb.journal.entry', string="Reconciled Lines", relation='qb_wizard_reconciled_lines_rel')
    difference = fields.Monetary(string="Difference", compute="_compute_difference", store=True, currency_field='currency_id')
    state = fields.Selection([
        ('draft', 'Draft'),
        ('in_progress', 'In Progress'),
        ('done', 'Done')
    ], string='Status', default='draft')
    session_id = fields.Many2one('qb.reconcile.session', string='Session')

    @api.depends('journal_id', 'date_from', 'date_to')
    def _compute_name(self):
        for rec in self:
            if rec.journal_id and rec.date_from and rec.date_to:
                rec.name = f"{rec.journal_id.name} ({rec.date_from} - {rec.date_to})"
            else:
                rec.name = "New Reconciliation"

    @api.depends('statement_line_ids', 'reconciled_line_ids', 'opening_balance', 'closing_balance')
    def _compute_difference(self):
        for rec in self:
            statement_balance = sum(rec.statement_line_ids.mapped('amount'))
            reconciled_balance = sum(rec.reconciled_line_ids.mapped('balance'))
            expected_difference = rec.closing_balance - rec.opening_balance
            rec.difference = expected_difference - (statement_balance + reconciled_balance)

    def action_start_reconciliation(self):
        self.ensure_one()
        if self.state == 'draft':
            self.state = 'in_progress'
            # Load journal items based on date range
            self.journal_item_ids = self.env['account.move.line'].search([
                ('journal_id', '=', self.journal_id.id),
                ('date', '>=', self.date_from),
                ('date', '<=', self.date_to),
                ('reconciled', '=', False)
            ])
        return self._get_reconciliation_view()

    def action_save_session(self):
        self.ensure_one()
        if not self.session_id:
            self.session_id = self.env['qb.reconcile.session'].create({
                'wizard_id': self.id,
                'date_saved': fields.Date.today(),
            })
        return {'type': 'ir.actions.act_window_close'}

    def action_validate_reconciliation(self):
        self.ensure_one()
        if abs(self.difference) > 0.01:
            raise UserError(_("Cannot validate reconciliation with non-zero difference"))
        
        # Create reconciliation for matched entries
        for line in self.reconciled_line_ids:
            if not line.reconciled:
                line.reconcile()
        
        self.state = 'done'
        return {'type': 'ir.actions.act_window_close'}

    def _get_reconciliation_view(self):
        return {
            'name': _('Bank Reconciliation'),
            'type': 'ir.actions.act_window',
            'res_model': 'qb.reconcile.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': 'current',
            'context': {'form_view_initial_mode': 'edit'},
        }
