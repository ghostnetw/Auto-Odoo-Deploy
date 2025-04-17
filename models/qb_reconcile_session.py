from odoo import models, fields, api


class QBReconcileSession(models.Model):
    _name = 'qb.reconcile.session'
    _description = 'Reconciliation Session'

    name = fields.Char(string='Name', compute='_compute_name', store=True)
    wizard_id = fields.Many2one('qb.reconcile.wizard', string='Reconciliation Wizard')
    date_saved = fields.Date(string='Saved Date')
    company_id = fields.Many2one(related='wizard_id.company_id', store=True)
    journal_id = fields.Many2one(related='wizard_id.journal_id', store=True)
    state = fields.Selection(related='wizard_id.state', store=True)

    @api.depends('wizard_id', 'date_saved')
    def _compute_name(self):
        for rec in self:
            if rec.wizard_id and rec.date_saved:
                rec.name = f"{rec.wizard_id.journal_id.name} - Saved on {rec.date_saved}"
            else:
                rec.name = "New Session"

    def action_continue_reconciliation(self):
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'qb.reconcile.wizard',
            'res_id': self.wizard_id.id,
            'view_mode': 'form',
            'target': 'current',
        }
