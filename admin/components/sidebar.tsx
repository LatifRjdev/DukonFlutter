'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Users,
  Store,
  CreditCard,
  Settings,
  Megaphone,
  ScrollText,
  LogOut,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const navItems = [
  { href: '/dashboard', label: 'Дашборд', icon: LayoutDashboard },
  { href: '/users', label: 'Пользователи', icon: Users },
  { href: '/stores', label: 'Магазины', icon: Store },
  { href: '/subscriptions', label: 'Подписки', icon: CreditCard },
  { href: '/subscriptions/plans', label: 'Тарифы', icon: Settings },
  { href: '/announcements', label: 'Объявления', icon: Megaphone },
  { href: '/audit-log', label: 'Журнал аудита', icon: ScrollText },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = () => {
    localStorage.removeItem('token');
    document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    router.push('/login');
  };

  const userName =
    typeof window !== 'undefined' ? localStorage.getItem('userName') : null;

  return (
    <aside className="flex h-screen w-60 flex-col border-r border-slate-200 bg-slate-900 text-white">
      {/* Logo */}
      <div className="flex items-center gap-2 px-6 py-5 border-b border-slate-700">
        <Store className="h-6 w-6 text-blue-400" />
        <span className="font-bold text-lg tracking-tight">DuckonPro Admin</span>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-4 px-3">
        <ul className="space-y-1">
          {navItems.map(({ href, label, icon: Icon }) => {
            const isActive =
              href === '/dashboard'
                ? pathname === '/dashboard'
                : pathname === href || pathname.startsWith(href + '/');
            return (
              <li key={href}>
                <Link
                  href={href}
                  className={cn(
                    'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-blue-600 text-white'
                      : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                  )}
                >
                  <Icon className="h-4 w-4 shrink-0" />
                  {label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* User & Logout */}
      <div className="border-t border-slate-700 p-4">
        <div className="mb-3 px-1">
          <p className="text-xs text-slate-400">Вы вошли как</p>
          <p className="text-sm font-medium text-white truncate">
            {userName || 'Администратор'}
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={handleLogout}
          className="w-full justify-start text-slate-300 hover:bg-slate-800 hover:text-white"
        >
          <LogOut className="mr-2 h-4 w-4" />
          Выйти
        </Button>
      </div>
    </aside>
  );
}
