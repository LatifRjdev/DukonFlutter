import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmDialog } from './confirm-dialog';

describe('ConfirmDialog', () => {
  it('renders nothing visible when open=false', () => {
    render(
      <ConfirmDialog
        open={false}
        onOpenChange={vi.fn()}
        title="Заблокировать пользователя?"
        description="Пользователь потеряет доступ немедленно."
        confirmLabel="Заблокировать"
        onConfirm={vi.fn()}
      />,
    );
    expect(screen.queryByText('Заблокировать пользователя?')).not.toBeInTheDocument();
  });

  it('shows title/description and calls onConfirm (not before) when confirm is clicked', async () => {
    const onConfirm = vi.fn();
    const onOpenChange = vi.fn();
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={onOpenChange}
        title="Заблокировать пользователя?"
        description="Пользователь потеряет доступ немедленно."
        confirmLabel="Заблокировать"
        onConfirm={onConfirm}
      />,
    );

    expect(screen.getByText('Заблокировать пользователя?')).toBeInTheDocument();
    expect(screen.getByText('Пользователь потеряет доступ немедленно.')).toBeInTheDocument();
    expect(onConfirm).not.toHaveBeenCalled();

    await userEvent.click(screen.getByRole('button', { name: 'Заблокировать' }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it('calls onOpenChange(false) and not onConfirm when "Отмена" is clicked', async () => {
    const onConfirm = vi.fn();
    const onOpenChange = vi.fn();
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={onOpenChange}
        title="Отменить подписку?"
        description="Магазин потеряет доступ к платным функциям."
        confirmLabel="Отменить подписку"
        onConfirm={onConfirm}
      />,
    );

    await userEvent.click(screen.getByRole('button', { name: 'Отмена' }));
    expect(onConfirm).not.toHaveBeenCalled();
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it('renders the confirm button in the destructive style when variant="destructive"', () => {
    render(
      <ConfirmDialog
        open={true}
        onOpenChange={vi.fn()}
        title="Удалить пользователя?"
        description="Это действие нельзя отменить."
        confirmLabel="Удалить"
        onConfirm={vi.fn()}
        variant="destructive"
      />,
    );
    // admin/components/ui/button.tsx doesn't render a `data-variant` DOM
    // attribute — variant only drives the cva-computed className. Assert on
    // the destructive variant's class instead (`text-destructive` is part of
    // its class list).
    expect(screen.getByRole('button', { name: 'Удалить' })).toHaveClass('text-destructive');
  });
});
