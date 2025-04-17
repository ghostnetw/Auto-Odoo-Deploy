from odoo import models, fields, api, _
from odoo.exceptions import UserError


class BankAccount(models.Model):
    _name = 'qb.bank.account'
    _description = 'Bank Account'

    name = fields.Char('Account Name', required=True)
    number = fields.Char('Account Number')
    currency_id = fields.Many2one('res.currency', string='Currency', required=True,
                                default=lambda self: self.env.company.currency_id)
    company_id = fields.Many2one('res.company', string='Company', required=True,
                                default=lambda self: self.env.company)
    balance = fields.Monetary(string='Current Balance', currency_field='currency_id')


class BankStatement(models.Model):
    _name = 'qb.bank.statement'
    _description = 'Bank Statement'
    _order = 'date desc'

    name = fields.Char('Reference', required=True)
    date = fields.Date('Date', required=True)
    amount = fields.Monetary('Amount', required=True, currency_field='currency_id')
    partner_id = fields.Many2one('res.partner', string='Partner')
    bank_account_id = fields.Many2one('qb.bank.account', string='Bank Account', required=True)
    currency_id = fields.Many2one(related='bank_account_id.currency_id')
    company_id = fields.Many2one(related='bank_account_id.company_id')
    state = fields.Selection([
        ('draft', 'Draft'),
        ('reconciled', 'Reconciled')
    ], string='Status', default='draft')
    notes = fields.Text('Notes')


class JournalEntry(models.Model):
    _name = 'qb.journal.entry'
    _description = 'Journal Entry'
    _order = 'date desc'

    name = fields.Char('Reference', required=True)
    date = fields.Date('Date', required=True)
    debit = fields.Monetary('Debit', currency_field='currency_id', default=0.0)
    credit = fields.Monetary('Credit', currency_field='currency_id', default=0.0)
    amount = fields.Monetary('Amount', currency_field='currency_id', compute='_compute_amount')
    partner_id = fields.Many2one('res.partner', string='Partner')
    bank_account_id = fields.Many2one('qb.bank.account', string='Bank Account', required=True)
    currency_id = fields.Many2one(related='bank_account_id.currency_id')
    company_id = fields.Many2one(related='bank_account_id.company_id')
    state = fields.Selection([
        ('draft', 'Draft'),
        ('reconciled', 'Reconciled')
    ], string='Status', default='draft')
    notes = fields.Text('Notes')

    @api.depends('debit', 'credit')
    def _compute_amount(self):
        for record in self:
            record.amount = record.debit - record.credit
