part of 'admin_employees_page.dart';

class _EmployeeEditorDialog extends StatefulWidget {
  const _EmployeeEditorDialog({this.employee});

  final EmployeeProfile? employee;

  @override
  State<_EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

class _EmployeeEditorDialogState extends State<_EmployeeEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _departmentController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _unitController;
  late final TextEditingController _expectedShiftStartController;
  late final TextEditingController _expectedShiftEndController;
  late final TextEditingController _notesController;

  late EmployeeStatus _status;
  late EmployeeWorkMode _workMode;
  late RoleLevel _roleLevel;
  late EmployeeAccessRole? _accessRole;
  bool _accessRoleChanged = false;
  late bool _requiresLocationOnPunch;
  late bool _trustedDeviceRequired;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.employee == null
        ? const EmployeeDraft(
            name: '',
            role: '',
            department: '',
            email: '',
            phone: '',
            unit: '',
            expectedShiftStart: TimeOfDay(hour: 8, minute: 0),
            expectedShiftEnd: TimeOfDay(hour: 17, minute: 0),
            status: EmployeeStatus.active,
            workMode: EmployeeWorkMode.onsite,
            roleLevel: RoleLevel.staff,
            requiresLocationOnPunch: true,
            trustedDeviceRequired: true,
            notes: '',
          )
        : EmployeeDraft.fromEmployee(widget.employee!);

    _nameController = TextEditingController(text: draft.name);
    _roleController = TextEditingController(text: draft.role);
    _departmentController = TextEditingController(text: draft.department);
    _emailController = TextEditingController(text: draft.email);
    _phoneController = TextEditingController(
      text: BrInputMasks.formatPhone(draft.phone),
    );
    _unitController = TextEditingController(text: draft.unit);
    _expectedShiftStartController = TextEditingController(
      text: _formatTimeOfDay(draft.expectedShiftStart),
    );
    _expectedShiftEndController = TextEditingController(
      text: _formatTimeOfDay(draft.expectedShiftEnd),
    );
    _notesController = TextEditingController(text: draft.notes);
    _status = draft.status;
    _workMode = draft.workMode;
    _roleLevel = draft.roleLevel;
    _accessRole = switch (widget.employee?.accessRole) {
      'employee' => EmployeeAccessRole.employee,
      'manager' => EmployeeAccessRole.manager,
      _ => draft.accessRole,
    };
    _requiresLocationOnPunch = draft.requiresLocationOnPunch;
    _trustedDeviceRequired = draft.trustedDeviceRequired;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _unitController.dispose();
    _expectedShiftStartController.dispose();
    _expectedShiftEndController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      EmployeeDraft(
        name: _nameController.text.trim(),
        role: _roleController.text.trim(),
        department: _departmentController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        unit: _unitController.text.trim(),
        expectedShiftStart: _parseTimeOfDay(_expectedShiftStartController.text),
        expectedShiftEnd: _parseTimeOfDay(_expectedShiftEndController.text),
        status: _status,
        workMode: _workMode,
        roleLevel: _roleLevel,
        accessRole: _isEditing && !_accessRoleChanged ? null : _accessRole,
        requiresLocationOnPunch: _requiresLocationOnPunch,
        trustedDeviceRequired: _trustedDeviceRequired,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isEditing ? 'Editar funcionário' : 'Novo funcionário',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preencha o payload do backend: dados principais, jornada, acesso, políticas e observações.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nome',
                    hintText: 'Ex.: Maria da Silva',
                    icon: Icons.person_outline_rounded,
                    validatorMessage: 'Informe o nome.',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _roleController,
                    label: 'Cargo',
                    hintText: 'Ex.: Analista Financeira',
                    icon: Icons.badge_outlined,
                    validatorMessage: 'Informe o cargo principal.',
                    minLength: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Departamento',
                    hintText: 'Ex.: Financeiro',
                    icon: Icons.apartment_rounded,
                    validatorMessage: 'Informe o departamento.',
                    minLength: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      hintText: 'Ex.: maria@empresa.com.br',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@') ||
                          !value.contains('.')) {
                        return 'Informe um e-mail válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Telefone',
                    hintText: 'Ex.: (11) 99999-0000',
                    icon: Icons.phone_outlined,
                    validatorMessage: 'Informe um telefone com DDD.',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [BrInputMasks.phoneFormatter],
                    validator: (value) {
                      final trimmedValue = value?.trim() ?? '';
                      if (trimmedValue.isEmpty) {
                        return 'Informe um telefone com DDD.';
                      }
                      if (!BrInputMasks.hasValidPhoneDigits(trimmedValue)) {
                        return 'Use um telefone com 10 ou 11 dígitos.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _unitController,
                    label: 'Unidade',
                    hintText: 'Ex.: Matriz Paulista',
                    icon: Icons.location_city_outlined,
                    validatorMessage: 'Informe a unidade de referência.',
                    minLength: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildShiftTimeField(
                          controller: _expectedShiftStartController,
                          label: 'Entrada prevista',
                          onTap: () => _pickShiftTime(
                            controller: _expectedShiftStartController,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildShiftTimeField(
                          controller: _expectedShiftEndController,
                          label: 'Saída prevista',
                          onTap: () => _pickShiftTime(
                            controller: _expectedShiftEndController,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAccessRoleEditor(),
                  const SizedBox(height: 16),
                  _buildStatusDropdown(),
                  const SizedBox(height: 16),
                  _buildWorkModeDropdown(),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _requiresLocationOnPunch,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exigir localização no ponto'),
                    onChanged: (value) {
                      setState(() {
                        _requiresLocationOnPunch = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _trustedDeviceRequired,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exigir dispositivo confiável'),
                    onChanged: (value) {
                      setState(() {
                        _trustedDeviceRequired = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      hintText: 'Ex.: Responsável pela operação da unidade.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _isEditing
                                    ? 'Salvar alterações'
                                    : 'Criar funcionário',
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: 220,
                            child: ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _isEditing
                                    ? 'Salvar alterações'
                                    : 'Criar funcionário',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    required IconData icon,
    required String validatorMessage,
    int minLength = 3,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String? value)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().length < minLength) {
              return validatorMessage;
            }
            return null;
          },
    );
  }

  Widget _buildShiftTimeField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:mm',
        prefixIcon: const Icon(Icons.schedule_rounded),
      ),
      validator: (value) {
        final trimmedValue = value?.trim() ?? '';
        if (trimmedValue.isEmpty) {
          return 'Informe um horário válido.';
        }
        final match = RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmedValue);
        if (!match) {
          return 'Use o formato HH:mm.';
        }
        return null;
      },
    );
  }

  Future<void> _pickShiftTime({
    required TextEditingController controller,
  }) async {
    final initialTime = controller.text.trim().isEmpty
        ? const TimeOfDay(hour: 8, minute: 0)
        : _parseTimeOfDay(controller.text);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (selectedTime == null) {
      return;
    }
    controller.text = _formatTimeOfDay(selectedTime);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.trim().split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<EmployeeStatus>(
      initialValue: _status,
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: EmployeeStatus.values.map((status) {
        return DropdownMenuItem<EmployeeStatus>(
          value: status,
          child: Text(_statusLabelForForm(status)),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _status = value;
        });
      },
    );
  }

  Widget _buildWorkModeDropdown() {
    return DropdownButtonFormField<EmployeeWorkMode>(
      initialValue: _workMode,
      decoration: const InputDecoration(
        labelText: 'Modo de trabalho',
        prefixIcon: Icon(Icons.work_outline_rounded),
      ),
      items: EmployeeWorkMode.values.map((workMode) {
        return DropdownMenuItem<EmployeeWorkMode>(
          value: workMode,
          child: Text(_workModeLabelForForm(workMode)),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _workMode = value;
        });
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<RoleLevel>(
      initialValue: _roleLevel,
      decoration: const InputDecoration(
        labelText: 'Nível',
        prefixIcon: Icon(Icons.shield_outlined),
      ),
      items: RoleLevel.values.map((roleLevel) {
        return DropdownMenuItem<RoleLevel>(
          value: roleLevel,
          child: Text(_roleLevelLabel(roleLevel)),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _roleLevel = value;
        });
      },
    );
  }

  Widget _buildAccessRoleDropdown() {
    return DropdownButtonFormField<EmployeeAccessRole?>(
      key: const ValueKey('employee-access-role-dropdown'),
      initialValue: _accessRole ?? EmployeeAccessRole.employee,
      decoration: const InputDecoration(
        labelText: 'Perfil de acesso',
        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
      ),
      items: <DropdownMenuItem<EmployeeAccessRole?>>[
        ...EmployeeAccessRole.values.map((accessRole) {
          return DropdownMenuItem<EmployeeAccessRole?>(
            value: accessRole,
            child: Text(_accessRoleLabelForForm(accessRole)),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _accessRole = value;
          _accessRoleChanged = true;
        });
      },
    );
  }

  Widget _buildAccessRoleEditor() {
    if (!_isEditing) {
      return _buildAccessRoleDropdown();
    }
    final employee = widget.employee!;
    if (employee.hasAccount == false) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.no_accounts_outlined),
        title: Text('Sem acesso ao sistema'),
      );
    }
    if (employee.hasAccount != true) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.help_outline_rounded),
        title: Text('Vínculo de acesso indisponível'),
      );
    }
    if (employee.accessRole == 'admin') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.admin_panel_settings_outlined),
        title: Text('Administrador (não editável)'),
      );
    }
    if (employee.accessRole != 'employee' && employee.accessRole != 'manager') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.help_outline_rounded),
        title: Text('Papel de acesso indisponível'),
      );
    }
    return _buildAccessRoleDropdown();
  }
}

String _statusLabelForForm(EmployeeStatus status) {
  return switch (status) {
    EmployeeStatus.active => 'Ativo',
    EmployeeStatus.onboarding => 'Onboarding',
    EmployeeStatus.onLeave => 'Afastado',
    EmployeeStatus.inactive => 'Inativo',
  };
}

String _workModeLabelForForm(EmployeeWorkMode workMode) {
  return switch (workMode) {
    EmployeeWorkMode.onsite => 'Presencial',
    EmployeeWorkMode.hybrid => 'Híbrido',
    EmployeeWorkMode.remote => 'Remoto',
  };
}

String _roleLevelLabel(RoleLevel roleLevel) {
  return switch (roleLevel) {
    RoleLevel.staff => 'Operacional',
    RoleLevel.specialist => 'Especialista',
    RoleLevel.leadership => 'Liderança',
  };
}

String _accessRoleLabelForForm(EmployeeAccessRole accessRole) {
  return switch (accessRole) {
    EmployeeAccessRole.employee => 'Funcionário',
    EmployeeAccessRole.manager => 'Gestor',
  };
}

class _EmployeeListTile extends StatelessWidget {
  const _EmployeeListTile({
    required this.employee,
    required this.selected,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.needsAttention,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final EmployeeProfile employee;
  final bool selected;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;
  final bool needsAttention;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.08)
                  : colorScheme.surface.withValues(alpha: 0.8),
              border: Border.all(
                color: selected ? AppTheme.accent : colorScheme.outlineVariant,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 560;
                return _buildContent(
                  context,
                  theme,
                  colorScheme,
                  isCompact: isCompact,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool isCompact,
  }) {
    final hasSignals =
        employee.status != EmployeeStatus.active || needsAttention;
    final showLeadingIcon = !isCompact;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLeadingIcon) ...<Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.16)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              border: Border.all(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.36)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              Icons.badge_rounded,
              size: 20,
              color: selected ? AppTheme.accent : colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Editar funcionário',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remover funcionário',
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${employee.role} | ${employee.department}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
              if (hasSignals) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  _compactSignalsLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _compactSignalsLabel() {
    final labels = <String>[
      if (employee.status != EmployeeStatus.active) statusLabel,
      if (needsAttention) 'Acompanhamento',
    ];
    return labels.join(' • ');
  }
}

class _AdminMetricItem extends StatelessWidget {
  const _AdminMetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.58),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  const _InlinePill({required this.label, required this.tone, this.icon});

  final String label;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDetailHero extends StatelessWidget {
  const _EmployeeDetailHero({
    required this.employee,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.workModeLabel,
    required this.workModeIcon,
    required this.needsAttention,
    required this.onEdit,
  });

  final EmployeeProfile employee;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String workModeLabel;
  final IconData workModeIcon;
  final bool needsAttention;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showIdentityIcon = MediaQuery.sizeOf(context).width >= 560;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;
          final identityBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showIdentityIcon) ...<Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    size: 28,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Perfil selecionado',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InlinePill(
                          label: statusLabel,
                          tone: statusColor,
                          icon: statusIcon,
                        ),
                        _InlinePill(
                          label: workModeLabel,
                          tone: colorScheme.onSurfaceVariant,
                          icon: workModeIcon,
                        ),
                        if (needsAttention)
                          const _InlinePill(
                            label: 'Atenção operacional',
                            tone: Color(0xFF8C5D00),
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      employee.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${employee.role} | ${employee.department}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.apartment_rounded,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            employee.unit,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                identityBlock,
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identityBlock),
              const SizedBox(width: 12),
              SizedBox(
                width: 128,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeNarrativeCard extends StatelessWidget {
  const _EmployeeNarrativeCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeOverviewCard extends StatelessWidget {
  const _EmployeeOverviewCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.88,
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDetailRow extends StatelessWidget {
  const _EmployeeDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePolicyRow extends StatelessWidget {
  const _EmployeePolicyRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              border: Border.all(color: tone.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedPunchEditorDialog extends StatefulWidget {
  const _ManagedPunchEditorDialog({required this.employee, this.punch});

  final EmployeeProfile employee;
  final ManagedPunchRecord? punch;

  @override
  State<_ManagedPunchEditorDialog> createState() =>
      _ManagedPunchEditorDialogState();
}

class _ManagedPunchEditorDialogState extends State<_ManagedPunchEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _timestampController;
  late final TextEditingController _detailController;
  late final TextEditingController _projectIdController;
  late DateTime _timestamp;
  late PunchType _type;

  bool get _isEditing => widget.punch != null;

  @override
  void initState() {
    super.initState();
    final initialPunch = widget.punch;
    _timestamp = initialPunch?.timestamp ?? DateTime.now();
    _type = initialPunch?.type ?? PunchType.checkIn;
    _timestampController = TextEditingController(
      text: _formatPunchTimestamp(_timestamp),
    );
    _detailController = TextEditingController(
      text: initialPunch?.detail ?? 'Ajuste manual de ponto.',
    );
    _projectIdController = TextEditingController(
      text: initialPunch?.projectId ?? '',
    );
  }

  @override
  void dispose() {
    _timestampController.dispose();
    _detailController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  Future<void> _pickTimestamp() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _timestamp,
    );
    if (date == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _timestampController.text = _formatPunchTimestamp(_timestamp);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      ManagedPunchDraft(
        type: _type,
        timestamp: _timestamp,
        detail: _detailController.text.trim(),
        projectId: _projectIdController.text.trim().isEmpty
            ? null
            : _projectIdController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isEditing ? 'Editar ponto' : 'Novo ponto manual',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Funcionário: ${widget.employee.name} | ${widget.employee.unit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<PunchType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de ponto',
                      prefixIcon: Icon(Icons.bolt_rounded),
                    ),
                    items: PunchType.values.map((type) {
                      return DropdownMenuItem<PunchType>(
                        value: type,
                        child: Text(_punchTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _type = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _timestampController,
                    readOnly: true,
                    onTap: _pickTimestamp,
                    decoration: const InputDecoration(
                      labelText: 'Data e hora',
                      hintText: 'Selecione a data e hora',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Informe data e hora do ponto.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _detailController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Detalhe',
                      hintText: 'Ex.: Ajuste manual aprovado pelo gestor.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Informe um detalhe com pelo menos 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _projectIdController,
                    decoration: const InputDecoration(
                      labelText: 'Projeto opcional',
                      hintText: 'ID do projeto',
                      prefixIcon: Icon(Icons.folder_open_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 560;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _isEditing
                                    ? 'Salvar alterações'
                                    : 'Criar ponto',
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _isEditing
                                    ? 'Salvar alterações'
                                    : 'Criar ponto',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagedPunchTile extends StatelessWidget {
  const _ManagedPunchTile({
    required this.punch,
    required this.onEdit,
    required this.onDelete,
  });

  final ManagedPunchRecord punch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = _punchTypeTone(punch.type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              border: Border.all(color: tone.withValues(alpha: 0.24)),
            ),
            child: Icon(_punchTypeIcon(punch.type), size: 17, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _InlinePill(
                      label: _punchTypeLabel(punch.type),
                      tone: tone,
                      icon: _punchTypeIcon(punch.type),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatPunchTimestamp(punch.timestamp),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  punch.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.25,
                  ),
                ),
                if (punch.projectId != null && punch.projectId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Projeto: ${punch.projectId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_ManagedPunchAction>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) {
              if (action == _ManagedPunchAction.edit) {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) {
              return const <PopupMenuEntry<_ManagedPunchAction>>[
                PopupMenuItem<_ManagedPunchAction>(
                  value: _ManagedPunchAction.edit,
                  child: Text('Editar'),
                ),
                PopupMenuItem<_ManagedPunchAction>(
                  value: _ManagedPunchAction.delete,
                  child: Text('Remover'),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

enum _ManagedPunchAction { edit, delete }

String _formatPunchTimestamp(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _punchTypeLabel(PunchType type) {
  return switch (type) {
    PunchType.checkIn => 'Entrada',
    PunchType.breakStart => 'Início de pausa',
    PunchType.breakEnd => 'Fim de pausa',
    PunchType.checkOut => 'Saída',
  };
}

IconData _punchTypeIcon(PunchType type) {
  return switch (type) {
    PunchType.checkIn => Icons.login_rounded,
    PunchType.breakStart => Icons.pause_circle_outline_rounded,
    PunchType.breakEnd => Icons.play_circle_outline_rounded,
    PunchType.checkOut => Icons.logout_rounded,
  };
}

Color _punchTypeTone(PunchType type) {
  return switch (type) {
    PunchType.checkIn => const Color(0xFF2F8F46),
    PunchType.breakStart => const Color(0xFFB26A00),
    PunchType.breakEnd => const Color(0xFF1F6F8B),
    PunchType.checkOut => const Color(0xFFB3261E),
  };
}
