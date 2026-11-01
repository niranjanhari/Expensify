(function() {
    var charts = {};

    function getTheme() {
        return document.documentElement.getAttribute('data-theme') || 'light';
    }

    function getThemeChartColors() {
        var isDark = getTheme() === 'dark';
        return {
            textColor: isDark ? '#F2F3ED' : '#191B18',
            secondaryColor: isDark ? '#A0A39A' : '#747871',
            gridColor: isDark ? '#30312B' : '#E8EAE5',
            donutEdge: isDark ? '#1A1B18' : '#FFFFFF',
            barOther: isDark ? '#45483F' : '#D3D7CE',
            barCurrent: '#D0F500'
        };
    }

    function updateThemeToggleUI() {
        var theme = getTheme();
        var label = document.getElementById('themeToggleText');
        if (label) {
            label.textContent = theme === 'dark' ? 'Dark' : 'Light';
        }
    }

    function toggleTheme() {
        var next = getTheme() === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('expensify-theme', next);
        updateThemeToggleUI();
        updateAllCharts();
    }

    function updateAllCharts() {
        var colors = getThemeChartColors();

        if (charts.dashboardDonut) {
            charts.dashboardDonut.data.datasets[0].borderColor = colors.donutEdge;
            charts.dashboardDonut.options.plugins.legend.labels.color = colors.textColor;
            charts.dashboardDonut.update();
        }

        if (charts.analyticsDonut) {
            charts.analyticsDonut.data.datasets[0].borderColor = colors.donutEdge;
            charts.analyticsDonut.options.plugins.legend.labels.color = colors.textColor;
            charts.analyticsDonut.update();
        }

        if (charts.analyticsBar) {
            var rawData = charts.analyticsBar._expensifyRaw || [];
            charts.analyticsBar.data.datasets[0].backgroundColor = rawData.map(function(item) {
                return item.is_current ? colors.barCurrent : colors.barOther;
            });
            charts.analyticsBar.options.scales.x.ticks.color = colors.textColor;
            charts.analyticsBar.options.scales.x.grid.color = 'transparent';
            charts.analyticsBar.options.scales.x.border.color = colors.gridColor;

            charts.analyticsBar.options.scales.y.ticks.color = colors.secondaryColor;
            charts.analyticsBar.options.scales.y.grid.color = colors.gridColor;
            charts.analyticsBar.options.scales.y.border.color = colors.gridColor;
            charts.analyticsBar.update();
        }
    }

    function openModal(modalId) {
        var modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('is-active');
            modal.setAttribute('aria-hidden', 'false');
            document.body.style.overflow = 'hidden';
        }
    }

    function closeModal(modalId) {
        var modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.remove('is-active');
            modal.setAttribute('aria-hidden', 'true');
            document.body.style.overflow = '';
        }
    }

    function openAddModal() {
        openModal('addExpenseModal');
        var input = document.getElementById('addAmount');
        if (input) {
            setTimeout(function() { input.focus(); }, 100);
        }
    }

    function openEditModal(id, amount, description, category, expenseDate, paymentMethod) {
        var form = document.getElementById('editExpenseForm');
        if (form) {
            form.action = '/expenses/edit/' + id;
        }
        var title = document.getElementById('editModalTitle');
        if (title) {
            title.textContent = 'Edit Expense #' + id;
        }
        var amtInput = document.getElementById('editAmount');
        if (amtInput) amtInput.value = amount;

        var descInput = document.getElementById('editDescription');
        if (descInput) descInput.value = description;

        var catSelect = document.getElementById('editCategory');
        if (catSelect) catSelect.value = category;

        var dateInput = document.getElementById('editDate');
        if (dateInput) dateInput.value = expenseDate;

        var pmSelect = document.getElementById('editPaymentMethod');
        if (pmSelect) pmSelect.value = paymentMethod;

        openModal('editExpenseModal');
    }

    function openDeleteModal(id, description, amountFormatted) {
        var form = document.getElementById('deleteExpenseForm');
        if (form) {
            form.action = '/expenses/delete/' + id;
        }
        var descElem = document.getElementById('deleteExpenseDesc');
        if (descElem) {
            descElem.textContent = description;
        }
        var amtElem = document.getElementById('deleteExpenseAmount');
        if (amtElem) {
            amtElem.textContent = amountFormatted;
        }
        openModal('deleteExpenseModal');
    }

    function initDashboardDonut(breakdownData) {
        var canvas = document.getElementById('dashboardDonutChart');
        var emptyMsg = document.getElementById('donutEmptyMessage');
        if (!canvas) return;

        if (!breakdownData || breakdownData.length === 0) {
            canvas.style.display = 'none';
            if (emptyMsg) emptyMsg.style.display = 'block';
            return;
        }

        canvas.style.display = 'block';
        if (emptyMsg) emptyMsg.style.display = 'none';

        var colors = getThemeChartColors();
        var labels = breakdownData.map(function(b) { return b.category; });
        var dataValues = breakdownData.map(function(b) { return b.total_rupees; });
        var bgColors = breakdownData.map(function(b) { return b.color; });

        if (charts.dashboardDonut) {
            charts.dashboardDonut.destroy();
        }

        charts.dashboardDonut = new Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: dataValues,
                    backgroundColor: bgColors,
                    borderColor: colors.donutEdge,
                    borderWidth: 2,
                    hoverOffset: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '65%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            color: colors.textColor,
                            font: { family: 'Inter', size: 11 },
                            padding: 12,
                            boxWidth: 10,
                            boxHeight: 10
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                var val = context.raw || 0;
                                return ' ' + context.label + ': ₹' + Number(val).toLocaleString('en-IN', { minimumFractionDigits: 2 });
                            }
                        }
                    }
                }
            }
        });
    }

    function initAnalyticsDonut(breakdownData) {
        var canvas = document.getElementById('analyticsDonutChart');
        var emptyMsg = document.getElementById('analyticsDonutEmptyMessage');
        if (!canvas) return;

        if (!breakdownData || breakdownData.length === 0) {
            canvas.style.display = 'none';
            if (emptyMsg) emptyMsg.style.display = 'block';
            return;
        }

        canvas.style.display = 'block';
        if (emptyMsg) emptyMsg.style.display = 'none';

        var colors = getThemeChartColors();
        var labels = breakdownData.map(function(b) { return b.category; });
        var dataValues = breakdownData.map(function(b) { return b.total_rupees; });
        var bgColors = breakdownData.map(function(b) { return b.color; });

        if (charts.analyticsDonut) {
            charts.analyticsDonut.destroy();
        }

        charts.analyticsDonut = new Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: dataValues,
                    backgroundColor: bgColors,
                    borderColor: colors.donutEdge,
                    borderWidth: 2,
                    hoverOffset: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '65%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            color: colors.textColor,
                            font: { family: 'Inter', size: 11 },
                            padding: 14,
                            boxWidth: 10,
                            boxHeight: 10
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                var val = context.raw || 0;
                                return ' ' + context.label + ': ₹' + Number(val).toLocaleString('en-IN', { minimumFractionDigits: 2 });
                            }
                        }
                    }
                }
            }
        });
    }

    function initAnalyticsBar(trendData) {
        var canvas = document.getElementById('analyticsBarChart');
        var emptyMsg = document.getElementById('analyticsBarEmptyMessage');
        if (!canvas) return;

        if (!trendData || trendData.length === 0) {
            canvas.style.display = 'none';
            if (emptyMsg) emptyMsg.style.display = 'block';
            return;
        }

        var totalAll = trendData.reduce(function(sum, item) { return sum + item.total_rupees; }, 0);
        if (totalAll === 0) {
            canvas.style.display = 'none';
            if (emptyMsg) emptyMsg.style.display = 'block';
            return;
        }

        canvas.style.display = 'block';
        if (emptyMsg) emptyMsg.style.display = 'none';

        var colors = getThemeChartColors();
        var labels = trendData.map(function(item) { return item.label; });
        var dataValues = trendData.map(function(item) { return item.total_rupees; });
        var bgColors = trendData.map(function(item) {
            return item.is_current ? colors.barCurrent : colors.barOther;
        });

        if (charts.analyticsBar) {
            charts.analyticsBar.destroy();
        }

        charts.analyticsBar = new Chart(canvas, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    data: dataValues,
                    backgroundColor: bgColors,
                    borderRadius: 4,
                    borderSkipped: false,
                    barPercentage: 0.55
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                var val = context.raw || 0;
                                return ' Spending: ₹' + Number(val).toLocaleString('en-IN', { minimumFractionDigits: 2 });
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        border: { color: colors.gridColor },
                        ticks: {
                            color: colors.textColor,
                            font: { family: 'Inter', size: 12 }
                        }
                    },
                    y: {
                        grid: { color: colors.gridColor },
                        border: { color: colors.gridColor },
                        ticks: {
                            color: colors.secondaryColor,
                            font: { family: 'Inter', size: 11 },
                            callback: function(value) {
                                return '₹' + Number(value).toLocaleString('en-IN');
                            }
                        }
                    }
                }
            }
        });
        charts.analyticsBar._expensifyRaw = trendData;
    }

    document.addEventListener('DOMContentLoaded', function() {
        updateThemeToggleUI();

        var themeBtn = document.getElementById('themeToggleBtn');
        if (themeBtn) {
            themeBtn.addEventListener('click', toggleTheme);
        }

        var openBtn = document.getElementById('openAddModalBtn');
        if (openBtn) {
            openBtn.addEventListener('click', openAddModal);
        }

        var mobileAddBtn = document.getElementById('mobileAddBtn');
        if (mobileAddBtn) {
            mobileAddBtn.addEventListener('click', openAddModal);
        }

        var closeBtn = document.getElementById('closeAddModalBtn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() { closeModal('addExpenseModal'); });
        }

        var cancelBtn = document.getElementById('cancelAddModalBtn');
        if (cancelBtn) {
            cancelBtn.addEventListener('click', function() { closeModal('addExpenseModal'); });
        }

        var closeEditBtn = document.getElementById('closeEditModalBtn');
        if (closeEditBtn) {
            closeEditBtn.addEventListener('click', function() { closeModal('editExpenseModal'); });
        }

        var cancelEditBtn = document.getElementById('cancelEditModalBtn');
        if (cancelEditBtn) {
            cancelEditBtn.addEventListener('click', function() { closeModal('editExpenseModal'); });
        }

        var closeDelBtn = document.getElementById('closeDeleteModalBtn');
        if (closeDelBtn) {
            closeDelBtn.addEventListener('click', function() { closeModal('deleteExpenseModal'); });
        }

        var cancelDelBtn = document.getElementById('cancelDeleteModalBtn');
        if (cancelDelBtn) {
            cancelDelBtn.addEventListener('click', function() { closeModal('deleteExpenseModal'); });
        }

        var mobileMenuBtn = document.getElementById('mobileMenuBtn');
        var sidebar = document.getElementById('sidebar');
        if (mobileMenuBtn && sidebar) {
            mobileMenuBtn.addEventListener('click', function() {
                sidebar.classList.toggle('is-open');
            });
        }

        var toggleDateCheckbox = document.getElementById('toggleDateRange');
        var dateFilterRow = document.getElementById('dateFilterRow');
        if (toggleDateCheckbox && dateFilterRow) {
            toggleDateCheckbox.addEventListener('change', function() {
                if (this.checked) {
                    dateFilterRow.classList.remove('is-hidden');
                } else {
                    dateFilterRow.classList.add('is-hidden');
                    var dateInputs = dateFilterRow.querySelectorAll('input[type="date"]');
                    dateInputs.forEach(function(inp) { inp.value = ''; });
                }
            });
        }

        var modals = document.querySelectorAll('.modal-backdrop');
        modals.forEach(function(modal) {
            modal.addEventListener('click', function(e) {
                if (e.target === modal) {
                    closeModal(modal.id);
                }
            });
        });

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                modals.forEach(function(modal) {
                    if (modal.classList.contains('is-active')) {
                        closeModal(modal.id);
                    }
                });
                if (sidebar && sidebar.classList.contains('is-open')) {
                    sidebar.classList.remove('is-open');
                }
            }
        });
    });

    window.Expensify = {
        openAddModal: openAddModal,
        openEditModal: openEditModal,
        openDeleteModal: openDeleteModal,
        closeModal: closeModal,
        toggleTheme: toggleTheme,
        initDashboardDonut: initDashboardDonut,
        initAnalyticsDonut: initAnalyticsDonut,
        initAnalyticsBar: initAnalyticsBar
    };
})();
