import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet , Router  } from '@angular/router';
import { HeaderComponent } from './header/header.component';
import { FooterComponent } from './footer/footer.component';

import { AuthService } from './services/auth.service';
import { User } from './models/user';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet,HeaderComponent,FooterComponent,CommonModule],
  templateUrl: './app.component.html',

})
export class AppComponent implements OnInit{
  title = 'shopfer';
  showNavbar = true;

  constructor(private readonly router: Router, private readonly as: AuthService)  {
    this.router.events.subscribe((val) => {
      // Check the current route, and hide the navbar if it's the login page
      this.showNavbar = !(this.router.url.includes('/login')||(this.router.url.includes('/sign-up')));
    });
  }

  ngOnInit(): void {
    this.as.user$.subscribe((user: User | null) => {
      if (user) {
        this.as.currentUserSig.set({
          email: user.email || '',           // Valeur par défaut si null/undefined
          userName: user.userName || 'Guest', // Valeur par défaut si null/undefined
        });
      } else {
        this.as.currentUserSig.set(null);
      }
    });
  }
}
