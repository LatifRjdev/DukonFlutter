import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

vi.mock('next/navigation', () => ({
  usePathname: () => '/dashboard',
  useRouter: () => ({ push: vi.fn() }),
}));

import { Sidebar } from './sidebar';

describe('Sidebar username display', () => {
  afterEach(() => {
    window.localStorage.clear();
  });

  it('shows the stored username once mounted, without branching on typeof window', async () => {
    window.localStorage.setItem('userName', 'Admin');

    render(<Sidebar />);

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());
  });

  it('falls back to "Администратор" when nothing is stored', async () => {
    render(<Sidebar />);

    await waitFor(() =>
      expect(screen.getByText('Администратор')).toBeInTheDocument(),
    );
  });
});
