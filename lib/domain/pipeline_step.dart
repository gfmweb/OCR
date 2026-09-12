enum PipelineStep {
  firstSpread,
  registration,
  review,
  encryption,
  send;

  String get label => switch (this) {
    PipelineStep.firstSpread => 'Разворот',
    PipelineStep.registration => 'Регистрация',
    PipelineStep.review => 'Редактирование и проверка',
    PipelineStep.encryption => 'Шифрование',
    PipelineStep.send => 'Отправка',
  };

  String get fullLabel => switch (this) {
    PipelineStep.firstSpread => 'Основной разворот паспорта',
    PipelineStep.registration => 'Страница регистрации',
    PipelineStep.review => 'Редактирование и проверка',
    PipelineStep.encryption => 'Шифрование данных',
    PipelineStep.send => 'Отправка пакета',
  };

  bool get isPlaceholder =>
      this == PipelineStep.encryption || this == PipelineStep.send;

  PipelineStep? get previous {
    if (index == 0) {
      return null;
    }
    return PipelineStep.values[index - 1];
  }

  PipelineStep? get next {
    if (index >= PipelineStep.values.length - 1) {
      return null;
    }
    return PipelineStep.values[index + 1];
  }
}
