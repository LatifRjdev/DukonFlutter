'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, ChevronDown, ChevronRight } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { DataTable, Column } from '@/components/data-table';
import { api } from '@/lib/api';
import { AuditLog } from '@/lib/types';
import { format } from 'date-fns';
import { cn } from '@/lib/utils';

const ACTION_COLORS: Record<string, string> = {
  CREATE: 'bg-green-100 text-green-700',
  UPDATE: 'bg-blue-100 text-blue-700',
  DELETE: 'bg-red-100 text-red-700',
  LOGIN: 'bg-purple-100 text-purple-700',
  LOGOUT: 'bg-gray-100 text-gray-700',
  APPROVE: 'bg-green-100 text-green-700',
  REJECT: 'bg-red-100 text-red-700',
  SUSPEND: 'bg-yellow-100 text-yellow-700',
  BLOCK: 'bg-red-100 text-red-700',
  UNBLOCK: 'bg-green-100 text-green-700',
};

const ACTIONS = ['CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'APPROVE', 'REJECT', 'SUSPEND', 'BLOCK', 'UNBLOCK'];

function ExpandableDetails({ details }: { details?: unknown }) {
  const [expanded, setExpanded] = useState(false);
  if (details == null) return <span className="text-muted-foreground text-xs">—</span>;
  const text =
    typeof details === 'string' ? details : JSON.stringify(details, null, 2);
  if (!text) return <span className="text-muted-foreground text-xs">—</span>;
  const short = text.length > 60 ? text.slice(0, 60) + '...' : text;

  return (
    <div className="max-w-xs">
      <button
        onClick={(e) => { e.stopPropagation(); setExpanded(!expanded); }}
        className="flex items-start gap-1 text-xs text-muted-foreground hover:text-foreground"
      >
        {expanded ? <ChevronDown className="h-3 w-3 mt-0.5 shrink-0" /> : <ChevronRight className="h-3 w-3 mt-0.5 shrink-0" />}
        <pre className="whitespace-pre-wrap font-mono text-left">
          {expanded ? text : short}
        </pre>
      </button>
    </div>
  );
}

export default function AuditLogPage() {
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');

  const { data: logs = [], isLoading } = useQuery<AuditLog[]>({
    queryKey: ['audit-log', actionFilter, dateFrom, dateTo],
    queryFn: () => {
      const params = new URLSearchParams();
      if (actionFilter !== 'all') params.set('action', actionFilter);
      if (dateFrom) params.set('from', dateFrom);
      if (dateTo) params.set('to', dateTo);
      return api.get(`/admin/audit-log?${params.toString()}`).then((r) => r.data ?? []);
    },
  });

  const filtered = logs.filter((l) => {
    if (!search) return true;
    const q = search.toLowerCase();
    const detailsText =
      typeof l.details === 'string'
        ? l.details
        : l.details != null
          ? JSON.stringify(l.details)
          : '';
    return (
      (l.user?.name?.toLowerCase().includes(q) ?? false) ||
      (l.user?.phone?.toLowerCase().includes(q) ?? false) ||
      (l.entityType?.toLowerCase().includes(q) ?? false) ||
      detailsText.toLowerCase().includes(q)
    );
  });

  const columns: Column<AuditLog>[] = [
    {
      key: 'date',
      header: 'Дата',
      cell: (l) => (
        <span className="text-xs text-muted-foreground whitespace-nowrap">
          {l.createdAt ? format(new Date(l.createdAt), 'dd.MM.yyyy HH:mm') : '—'}
        </span>
      ),
    },
    {
      key: 'user',
      header: 'Пользователь',
      cell: (l) => <span className="text-sm">{l.user?.name || l.user?.phone || l.userId || '—'}</span>,
    },
    {
      key: 'action',
      header: 'Действие',
      cell: (l) => (
        <Badge
          className={cn(
            ACTION_COLORS[l.action] || 'bg-gray-100 text-gray-700',
            'hover:opacity-80 font-mono text-xs'
          )}
        >
          {l.action}
        </Badge>
      ),
    },
    {
      key: 'entity',
      header: 'Сущность',
      cell: (l) => (
        <div>
          <span className="text-sm font-medium">{l.entityType}</span>
          {l.entityId && (
            <p className="text-xs text-muted-foreground font-mono">{l.entityId}</p>
          )}
        </div>
      ),
    },
    {
      key: 'details',
      header: 'Детали',
      cell: (l) => <ExpandableDetails details={l.details} />,
    },
    {
      key: 'ip',
      header: 'IP',
      cell: (l) => (
        <span className="text-xs font-mono text-muted-foreground">{l.ip || '—'}</span>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Журнал аудита</h1>
        <p className="text-muted-foreground text-sm mt-1">
          История действий в системе
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Поиск по пользователю, сущности..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <Select value={actionFilter} onValueChange={(v) => v != null && setActionFilter(v)}>
          <SelectTrigger className="w-40">
            <SelectValue placeholder="Действие" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Все действия</SelectItem>
            {ACTIONS.map((a) => (
              <SelectItem key={a} value={a}>
                {a}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <div className="flex items-center gap-2">
          <Input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className="w-36 text-sm"
            placeholder="С"
          />
          <span className="text-muted-foreground text-sm">—</span>
          <Input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className="w-36 text-sm"
            placeholder="По"
          />
        </div>
      </div>

      <DataTable
        data={filtered}
        columns={columns}
        isLoading={isLoading}
        emptyMessage="Нет записей в журнале"
        pageSize={20}
      />
    </div>
  );
}
