odoo.define('qb_style_bank_reconcile.reconcile', function (require) {
    'use strict';

    var FormController = require('web.FormController');
    var FormView = require('web.FormView');
    var viewRegistry = require('web.view_registry');
    var core = require('web.core');
    var _t = core._t;

    var QBReconcileFormController = FormController.extend({
        events: _.extend({}, FormController.prototype.events, {
            'click .o_list_record_selector input': '_onSelectRecord',
            'click .o_qb_search_button': '_onSearch',
            'keyup .o_qb_search_input': '_onSearchInput',
            'click .o_qb_sort_column': '_onSortColumn',
        }),

        init: function () {
            this._super.apply(this, arguments);
            this.sortOrder = 'asc';
            this.sortField = 'date';
        },

        _onSelectRecord: function (ev) {
            var $row = $(ev.currentTarget).closest('tr');
            $row.toggleClass('o_selected_row');
            this._updateReconciled();
        },

        _updateReconciled: function () {
            var self = this;
            var selectedIds = [];
            this.$('.o_selected_row').each(function () {
                var recordId = $(this).data('id');
                if (recordId) {
                    selectedIds.push(recordId);
                }
            });

            this._rpc({
                model: 'qb.reconcile.wizard',
                method: 'write',
                args: [[this.initialState.data.id], {
                    reconciled_line_ids: [[6, 0, selectedIds]]
                }],
            }).then(function () {
                self.update({}, {reload: true});
                self._updateDifferenceStyle();
            });
        },

        _onSearch: function () {
            var searchValue = this.$('.o_qb_search_input').val().toLowerCase();
            this.$('.o_data_row').each(function () {
                var $row = $(this);
                var text = $row.text().toLowerCase();
                $row.toggle(text.indexOf(searchValue) !== -1);
            });
        },

        _onSearchInput: function (ev) {
            if (ev.keyCode === 13) {  // Enter key
                this._onSearch();
            }
        },

        _onSortColumn: function (ev) {
            var field = $(ev.currentTarget).data('field');
            if (field === this.sortField) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = field;
                this.sortOrder = 'asc';
            }

            var $tbody = this.$('tbody');
            var rows = $tbody.find('tr').get();

            rows.sort((a, b) => {
                var aVal = $(a).find(`[data-field="${field}"]`).text();
                var bVal = $(b).find(`[data-field="${field}"]`).text();
                
                if (field === 'date') {
                    aVal = new Date(aVal);
                    bVal = new Date(bVal);
                } else if (field === 'amount' || field === 'debit' || field === 'credit') {
                    aVal = parseFloat(aVal) || 0;
                    bVal = parseFloat(bVal) || 0;
                }

                if (this.sortOrder === 'asc') {
                    return aVal > bVal ? 1 : -1;
                } else {
                    return aVal < bVal ? 1 : -1;
                }
            });

            $tbody.empty().append(rows);
        },

        _updateDifferenceStyle: function () {
            var difference = parseFloat(this.$('.o_field_float[name="difference"]').text());
            var $differenceField = this.$('.o_field_float[name="difference"]');
            
            if (Math.abs(difference) < 0.01) {
                $differenceField.removeClass('difference_nonzero').addClass('difference_zero');
            } else {
                $differenceField.removeClass('difference_zero').addClass('difference_nonzero');
            }
        },

        renderButtons: function () {
            this._super.apply(this, arguments);
            if (this.$buttons) {
                this.$buttons.find('.o_form_button_create').hide();
            }
        },

        _update: function () {
            var self = this;
            return this._super.apply(this, arguments).then(function () {
                self._updateDifferenceStyle();
            });
        }
    });

    var QBReconcileFormView = FormView.extend({
        config: _.extend({}, FormView.prototype.config, {
            Controller: QBReconcileFormController,
        }),
    });

    viewRegistry.add('qb_reconcile_form', QBReconcileFormView);

    return {
        QBReconcileFormController: QBReconcileFormController,
        QBReconcileFormView: QBReconcileFormView,
    };
});
